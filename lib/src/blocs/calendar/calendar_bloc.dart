import 'dart:async';
import 'dart:io';

import 'package:LuxCal/src/models/news_model.dart'; // Ensure this import path is correct
import 'package:LuxCal/src/models/event_model.dart'; // Assuming you have an Event model; add this import if needed
import 'package:LuxCal/src/models/user_model.dart';
import 'package:LuxCal/src/services/api/fetch_jew_holidays.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:table_calendar/table_calendar.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<int> gottenYears = [];

  CalendarBloc() : super(CalendarState.initial()) {
    on<DaySelected>(_onDaySelected);
    on<YearSelected>(_onYearSelected);
    on<ChangeTab>(_onChangeTab);
    on<InilaizeCalendar>(_initialzeCalendar);
    on<AddEvent>(_onAddEvent);
    on<AddNews>(_onAddNews);
    on<DeleteEvent>(_onDeleteEvent);
    on<DeleteNews>(_onDeleteNews);
    on<UpdateEvent>(_onUpdateEvent);
    on<UpdateNews>(_onUpdateNews);
    on<GetHolidaysForYear>(_onGetHolidaysForYear);
    add(InilaizeCalendar());
  }
  Future<void> _onGetHolidaysForYear(
      GetHolidaysForYear event, Emitter<CalendarState> emit) async {
    if (gottenYears.contains(event.year)) {
      return;
    }
    gottenYears.add(event.year);
    try {
      // Fetch holiday events for the given year
      final holidayEvents = await fetchHolidays(event.year);

      // Fetch the existing events from the state or Firestore
      final existingEvents = state.events ?? await _getEvents();

      // Combine the existing events with the holiday events
      final allEvents = List<EventModel>.from(existingEvents)
        ..addAll(holidayEvents);

      // Emit the updated state with the combined events list
      emit(state.copyWith(events: allEvents));
    } catch (error) {
      print("Failed to fetch holiday events: $error");
      // Optionally, handle the error by emitting a failure state or showing a message
    }
  }

  Future<void> _onUpdateEvent(
      UpdateEvent event, Emitter<CalendarState> emit) async {
    try {
      String? pickedImage;
      print(pickedImage);
      if (event.pickedImage != null) {
        pickedImage = await _uploadImageToStorage(
            event.pickedImage!, 'event/${event.updatedEvent.id}/image.jpg');
      }

      final docRef = await _firestore
          .collection('events')
          .where("id", isEqualTo: event.updatedEvent.id)
          .get()
          .then((value) => value.docs.first.reference);
      if (event.pickedImage != null) {
        final finalEvent = event.updatedEvent.copyWith(imageUrl: pickedImage);
        await docRef.update(finalEvent.toFirestore());
      } else {
        await docRef.update(event.updatedEvent.toFirestore());
      }

      // List<EventModel> updatedEvents = await _getEvents();

      add(InilaizeCalendar());

      // emit(state.copyWith(events: updatedEvents));
    } catch (error) {
      print("Failed to update event: $error");
    }
  }

  Future<void> _onUpdateNews(
      UpdateNews event, Emitter<CalendarState> emit) async {
    try {
      String? pickedImage;
      if (event.pickedImage != null) {
        if (event.pickedImage != null) {
          pickedImage = await _uploadImageToStorage(
              event.pickedImage!, 'news/${event.updatedNews.id}/image.jpg');
        }
      }

      final docRef = await _firestore
          .collection('news')
          .where("id", isEqualTo: event.updatedNews.id)
          .get()
          .then((value) => value.docs.first.reference);

      if (event.pickedImage != null) {
        final finalNews = event.updatedNews.copyWith(imageUrl: pickedImage);
        await docRef.update(finalNews.toFirestore());
      } else {
        await docRef.update(event.updatedNews.toFirestore());
      }
      List<NewsModel> updatedNews = await _getNews();
      emit(state.copyWith(news: updatedNews));
    } catch (error) {
      print("Failed to update news: $error");
    }
  }

  Future<void> _onDeleteEvent(
      DeleteEvent event, Emitter<CalendarState> emit) async {
    try {
      // Delete the event from Firestore
      await _firestore
          .collection('events')
          .where("id", isEqualTo: event.eventId)
          .get()
          .then(
        (value) {
          for (var doc in value.docs) {
            doc.reference.delete();
          }
        },
      );

      // Assuming `state.events` is a List<EventModel>, remove the event with eventId from this list
      // Note: This requires EventModel to be comparable (e.g., override equals/hashCode or use a unique identifier for comparison)
      final List<EventModel> remainingEvents = state.events != null
          ? state.events!.where((e) => e.id != event.eventId).toList()
          : [];

      // Emit the updated state with the remaining events
      emit(state.copyWith(events: remainingEvents));
    } catch (error) {
      print("Failed to delete event: $error");
      // Optionally, handle the error by emitting a failure state or showing a message
    }
  }

  Future<void> _onDeleteNews(
      DeleteNews event, Emitter<CalendarState> emit) async {
    try {
      // Delete the event from Firestore
      await _firestore
          .collection('news')
          .where("id", isEqualTo: event.newsId)
          .get()
          .then(
        (value) {
          value.docs.first.reference.delete();
        },
      );

      // Fetch the updated list of events
      List<NewsModel> updatedNews = await _getNews();

      // Emit the new state with the updated events list
      emit(state.copyWith(news: updatedNews));
    } catch (error) {
      print("Failed to delete event: $error");
      // Optionally, handle the error by emitting a failure state or showing a message
    }
  }

  void _onAddNews(AddNews event, Emitter<CalendarState> emit) async {
    try {
      String? imageUrl;
      if (event.image != null) {
        // IMPORTANT: use putData(...) for cross-platform.
        // So we read the bytes from XFile:
        imageUrl = await _uploadImageToStorage(
          event.image!,
          'news/${event.news.id}/image.jpg',
        );
      }

      // Add the doc with the optional imageUrl
      await _firestore
          .collection('news')
          .add(event.news.copyWith(imageUrl: imageUrl).toFirestore());

      // Retrieve updated news
      List<NewsModel> updatedNews = await _getNews();
      emit(state.copyWith(news: updatedNews));
    } catch (error) {
      print(error);
      // Possibly emit an error state or show an error message
    }
  }

  FutureOr<void> _onAddEvent(
      AddEvent event, Emitter<CalendarState> emit) async {
    try {
      String? imageUrl;
      if (event.image != null) {
        imageUrl = await _uploadImageToStorage(
            event.image!, 'events/${event.event.id}/image.jpg');
      }

      // Create a copy of the event with the imageUrl, if it exists
      final newEvent = event.event.copyWith(imageUrl: imageUrl);

      // Add the event to Firestore
      await _firestore.collection('events').add(newEvent.toFirestore());

      // Check if state.events is null. If so, initialize an empty list; otherwise, use the existing list.
      final List<EventModel> currentEvents = state.events ?? [];

      // Append the new event to the list of current events.
      final List<EventModel> updatedEvents =
          List<EventModel>.from(currentEvents)..add(newEvent);

      // Emit the updated state with the new list of events
      emit(state.copyWith(events: updatedEvents));
    } catch (error) {
      print(error);
    }
  }

  void _onDaySelected(DaySelected event, Emitter<CalendarState> emit) async {
    emit(state.copyWith(
      selectedDay: event.selectedDay,
      focusedDay: event.focusedDay,
    ));
  }

  void _onYearSelected(YearSelected event, Emitter<CalendarState> emit) {
    emit(state.copyWith(focusedDay: event.focusedDay));
  }

  FutureOr<void> _onChangeTab(ChangeTab event, Emitter<CalendarState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  void _initialzeCalendar(
      InilaizeCalendar event, Emitter<CalendarState> emit) async {
    print("object");
    emit(state.copyWith(status: CalendarStatus.loadingInfo));
    final contacts = await _getContacts();
    final existingEvents = await _getEvents(); // Events from Firestore

    // Generate occurrences for each event and gather them into a new list
    final List<EventModel> allEventsWithOccurrences = [];
    for (var event in existingEvents) {
      final occurrences =
          generateMonthlyOccurrences(event, DateTime.now().year);
      allEventsWithOccurrences.addAll(occurrences);
    }

    final currentYear = DateTime.now().year;
    gottenYears.add(currentYear);
    final holidayEvents = await fetchHolidays(
        currentYear); // Fetch holiday events for the current year
    final news = await _getNews(); // Fetch news

    // Combine all events and occurrences
    final allEvents = List<EventModel>.from(allEventsWithOccurrences)
      ..addAll(holidayEvents);

    emit(state.copyWith(
      contacts: contacts,
      events: allEvents,
      news: news,
      status: CalendarStatus.loaded,
    ));
  }

  List<EventModel> generateMonthlyOccurrences(EventModel event, int year) {
    List<EventModel> occurrences = [];
    DateTime startDate = event.startDate;
    DateTime endDate = event.endDate;

    // Add the original event if it falls within the specified year
    if (startDate.year == year) {
      occurrences.add(event);
    }

    if (event.hebrewFormat == true) {
      try {
        JewishDate hebrewStartDate = JewishDate.fromDateTime(startDate);
        JewishDate hebrewEndDate = JewishDate.fromDateTime(endDate);

        // Calculate the duration between start and end for Hebrew events
        Duration eventDuration = endDate.difference(startDate);

        switch (event.recurrence) {
          case 'Every Day':
            for (int i = 1; i <= 365; i++) {
              hebrewStartDate =
                  JewishDate.fromDateTime(startDate.add(Duration(days: i)));
              DateTime newGregorianStart =
                  hebrewStartDate.getGregorianCalendar();

              if (newGregorianStart.year <= year + 1) {
                DateTime newGregorianEnd = newGregorianStart.add(eventDuration);
                occurrences.add(event.copyWith(
                  startDate: newGregorianStart,
                  endDate: newGregorianEnd,
                ));
              }
            }
            break;

          case 'Once a Week':
            for (int i = 1; i <= 52; i++) {
              hebrewStartDate =
                  JewishDate.fromDateTime(startDate.add(Duration(days: i * 7)));
              DateTime newGregorianStart =
                  hebrewStartDate.getGregorianCalendar();

              if (newGregorianStart.year <= year + 1) {
                DateTime newGregorianEnd = newGregorianStart.add(eventDuration);
                occurrences.add(event.copyWith(
                  startDate: newGregorianStart,
                  endDate: newGregorianEnd,
                ));
              }
            }
            break;

          case 'Once a Month':
            // For Hebrew monthly recurrence, advance by Hebrew months
            int originalJewishMonth = hebrewStartDate.getJewishMonth();
            int originalJewishDay = hebrewStartDate.getJewishDayOfMonth();
            int currentYear = hebrewStartDate.getJewishYear();

            for (int monthsToAdd = 1; monthsToAdd <= 24; monthsToAdd++) {
              try {
                int newMonth = originalJewishMonth + monthsToAdd;
                int newYear = currentYear;

                // Handle year rollover
                while (newMonth > 12) {
                  if (JewishDate().isJewishLeapYear() && newMonth > 13) {
                    newMonth -= 13;
                    newYear++;
                  } else if (!JewishDate().isJewishLeapYear()) {
                    newMonth -= 12;
                    newYear++;
                  } else {
                    break;
                  }
                }

                // Create new Hebrew date
                JewishDate newHebrewDate = JewishDate.initDate(
                    jewishYear: newYear,
                    jewishMonth: newMonth,
                    jewishDayOfMonth: originalJewishDay);
                DateTime newGregorianStart =
                    newHebrewDate.getGregorianCalendar();

                if (newGregorianStart.year <= year + 1) {
                  DateTime newGregorianEnd =
                      newGregorianStart.add(eventDuration);
                  occurrences.add(event.copyWith(
                    startDate: newGregorianStart,
                    endDate: newGregorianEnd,
                  ));
                }
              } catch (e) {
                print("Error creating Hebrew monthly occurrence: $e");
                continue;
              }
            }
            break;

          case 'Once a Year':
            // For Hebrew yearly recurrence (like Yahrzeit)
            int originalJewishMonth = hebrewStartDate.getJewishMonth();
            int originalJewishDay = hebrewStartDate.getJewishDayOfMonth();
            int startingYear = hebrewStartDate.getJewishYear();

            for (int yearsToAdd = 1; yearsToAdd <= 5; yearsToAdd++) {
              try {
                int newJewishYear = startingYear + yearsToAdd;
                JewishDate newHebrewDate = JewishDate.initDate(
                    jewishYear: newJewishYear,
                    jewishMonth: originalJewishMonth,
                    jewishDayOfMonth: originalJewishDay);
                DateTime newGregorianStart =
                    newHebrewDate.getGregorianCalendar();

                if (newGregorianStart.year <= year + 1) {
                  DateTime newGregorianEnd =
                      newGregorianStart.add(eventDuration);
                  occurrences.add(event.copyWith(
                    startDate: newGregorianStart,
                    endDate: newGregorianEnd,
                  ));
                }
              } catch (e) {
                print("Error creating Hebrew yearly occurrence: $e");
                continue;
              }
            }
            break;

          default:
            break;
        }
      } catch (e) {
        print("Error processing Hebrew date: $e");
        // Fall back to original event only
      }
    } else {
      // Gregorian calendar logic (unchanged)
      switch (event.recurrence) {
        case 'Every Day':
          DateTime currentStart = startDate;
          DateTime currentEnd = endDate;

          while (currentStart.year == year) {
            currentStart = currentStart.add(Duration(days: 1));
            currentEnd = currentEnd.add(Duration(days: 1));
            if (currentStart.year == year) {
              occurrences.add(
                  event.copyWith(startDate: currentStart, endDate: currentEnd));
            }
          }
          break;

        case 'Once a Week':
          DateTime currentStart = startDate;
          DateTime currentEnd = endDate;

          while (currentStart.year == year) {
            currentStart = currentStart.add(Duration(days: 7));
            currentEnd = currentEnd.add(Duration(days: 7));
            if (currentStart.year == year) {
              occurrences.add(
                  event.copyWith(startDate: currentStart, endDate: currentEnd));
            }
          }
          break;

        case 'Once a Month':
          DateTime currentStart = startDate;
          DateTime currentEnd = endDate;

          while (currentStart.year == year) {
            // Properly handle month advancement
            int newMonth = currentStart.month + 1;
            int newYear = currentStart.year;
            if (newMonth > 12) {
              newMonth = 1;
              newYear++;
            }

            try {
              currentStart = DateTime(newYear, newMonth, currentStart.day,
                  currentStart.hour, currentStart.minute);
              currentEnd = DateTime(newYear, newMonth, currentEnd.day,
                  currentEnd.hour, currentEnd.minute);

              if (currentStart.year == year) {
                occurrences.add(event.copyWith(
                    startDate: currentStart, endDate: currentEnd));
              }
            } catch (e) {
              // Handle invalid dates (e.g., Feb 30)
              break;
            }
          }
          break;

        case 'Once a Year':
          DateTime currentStart = startDate;
          DateTime currentEnd = endDate;

          while (currentStart.year <= year + 5) {
            currentStart = DateTime(currentStart.year + 1, currentStart.month,
                currentStart.day, currentStart.hour, currentStart.minute);
            currentEnd = DateTime(currentEnd.year + 1, currentEnd.month,
                currentEnd.day, currentEnd.hour, currentEnd.minute);

            if (currentStart.year == year) {
              occurrences.add(
                  event.copyWith(startDate: currentStart, endDate: currentEnd));
            }
          }
          break;

        default:
          break;
      }
    }
    return occurrences;
  }

  // Retrieves the contacts from Firestore and updates the state.
  Future<List<UserModel>> _getContacts() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // Retrieves the events from Firestore and updates the state.
  Future<List<EventModel>> _getEvents() async {
    final snapshot = await _firestore.collection('events').get();
    return snapshot.docs
        .map((doc) => EventModel.fromFirestore(doc.data()))
        .toList();
  }

  // Retrieves news from Firestore and updates the state.
  Future<List<NewsModel>> _getNews() async {
    final snapshot = await _firestore.collection('news').get();
    return snapshot.docs
        .map((doc) => NewsModel.fromFirestore(doc.data()))
        .toList();
  }

  Future<String> _uploadImageToStorage(XFile image, String targetPath) async {
    try {
      // 1. Read the bytes from the XFile (works on Web, iOS, and Android).
      final data = await image.readAsBytes();

      // 2. Create a reference to Firebase Storage.
      final ref = _storage.ref(targetPath);

      // 3. Upload the file bytes using putData instead of putFile.
      final uploadTask = await ref.putData(data);

      // 4. Once the file upload is complete, get the download URL.
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 5. Return the download URL of the image
      return downloadUrl;
    } catch (e) {
      print(e); // Consider logging to a service or console.
      throw e;
    }
  }
}
