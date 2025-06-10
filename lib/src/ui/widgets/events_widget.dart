import 'package:LuxCal/core/theme/pallette.dart';
import 'package:LuxCal/core/theme/typography.dart';
import 'package:LuxCal/src/blocs/calendar/calendar_bloc.dart';
import 'package:LuxCal/src/models/event_model.dart';
import 'package:LuxCal/src/models/news_model.dart';
import 'package:LuxCal/src/ui/widgets/elevated_container_card.dart';
import 'package:LuxCal/src/ui/widgets/spacer.dart';
import 'package:LuxCal/src/utils/screen_size.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EventsWidget extends StatefulWidget {
  const EventsWidget({super.key});

  @override
  State<EventsWidget> createState() => _EventsWidgetState();
}

class _EventsWidgetState extends State<EventsWidget> {
  int tabIndex = 1;
  Alignment alignment = Alignment(-1, -1);

  void chooseTab(int index) {
    setState(() {
      tabIndex = index;
    });
  }

  List<EventModel> filterAndSortUpcomingEvents(List<EventModel>? events) {
    if (events == null) return [];
    final now = DateTime.now();
    final twoWeeksFromNow = now.add(Duration(days: 14));

    // Get today's date at start of day for comparison
    final todayStart = DateTime(now.year, now.month, now.day);

    // Filter events to get those that are happening today OR in the future (within 2 weeks)
    final upcomingEvents = events.where((event) {
      final eventStart = DateTime(
          event.startDate.year, event.startDate.month, event.startDate.day);
      final eventEnd =
          DateTime(event.endDate.year, event.endDate.month, event.endDate.day);

      // Include events that:
      // 1. Start today or in the future
      // 2. Are currently ongoing (started before today but end today or later)
      // 3. Are within the next 2 weeks
      return (eventStart.isAtSameMomentAs(todayStart) ||
              eventStart.isAfter(todayStart) ||
              (eventStart.isBefore(todayStart) &&
                  (eventEnd.isAtSameMomentAs(todayStart) ||
                      eventEnd.isAfter(todayStart)))) &&
          eventStart.isBefore(twoWeeksFromNow);
    }).toList();

    // Sort the filtered events by startDate
    upcomingEvents.sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcomingEvents;
  }

  // Also fix the event tile to show "Today" for today's events
  Widget _eventTile(EventModel event) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final eventStart = DateTime(
        event.startDate.year, event.startDate.month, event.startDate.day);

    String timeText;
    if (eventStart.isAtSameMomentAs(todayStart)) {
      timeText = "Today";
    } else {
      final daysDifference = eventStart.difference(todayStart).inDays;
      timeText = "In $daysDifference Days";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          context.push('/selectedEvent', extra: event);
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
              color: event.color,
              borderRadius: BorderRadius.all(Radius.circular(20))),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12, left: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    event.title ?? 'No Title',
                    style: AppTypography.calendarDays
                        .copyWith(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    timeText,
                    style: AppTypography.calendarDays
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<NewsModel> filterAndSortNews(List<NewsModel>? news) {
    if (news == null) return [];
    news.sort((a, b) => b.publicationDate.compareTo(a.publicationDate));
    return news;
  }

  List<EventModel> filterAndSortSelectedDayEvents(
      List<EventModel>? events, DateTime selectedDay) {
    if (events == null) return [];

    // Filter events for the selected day. This includes events that:
    // - Start on the selected day
    // - End on the selected day
    // - Span across the selected day
    final eventsForSelectedDay = events.where((event) {
      final startDay = DateTime(
          event.startDate.year, event.startDate.month, event.startDate.day);
      final endDay =
          DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
      final checkDay =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

      return checkDay.isAtSameMomentAs(startDay) ||
          (checkDay.isAfter(startDay) && checkDay.isBefore(endDay)) ||
          checkDay.isAtSameMomentAs(endDay);
    }).toList();

    // Sort the filtered events by start time
    eventsForSelectedDay.sort((a, b) => a.startDate.compareTo(b.startDate));

    return eventsForSelectedDay;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CalendarBloc, CalendarState>(
      listener: (context, state) {},
      builder: (context, state) {
        final upcomingEvents = filterAndSortUpcomingEvents(state.events);
        final news = filterAndSortNews(state.news); // Fetch news from state
        final selectedDayEvents =
            filterAndSortSelectedDayEvents(state.events, state.selectedDay);
        return Container(
          width: context.width,
          color: Color.fromARGB(0, 0, 0, 0),
          child: Stack(
            children: [
              tabContainers(context, state),
              Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: ElevatedContainerCard(
                  width: context.width,
                  height: context.height * 0.25,
                  boxShaow: BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 20),
                  ),
                  child: Padding(
                      padding: const EdgeInsets.only(
                          left: 8, right: 8, top: 15, bottom: 15),
                      child: switch (tabIndex) {
                        1 => _listBuilderEvents(upcomingEvents),
                        2 => _listBuilderNews(news),
                        3 => _listBuilderSelectedDay(selectedDayEvents),
                        int() => null,
                      }),
                ),
              ),
              Align(
                alignment: const Alignment(0.95, -0.99),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: AppPalette.jacarta,
                          title: Center(
                            child: Text("Add",
                                style: AppTypography.buttonText
                                    .copyWith(fontSize: 24)),
                          ),
                          content: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                      Color(0xff008080),
                                    ), // Replace with your color
                                  ),
                                  onPressed: () {
                                    context.pop();

                                    context.push("/addEvent");
                                  },
                                  child: Text("Event",
                                      style: AppTypography.buttonText
                                          .copyWith(fontSize: 16))),
                              spacerWidth(20),
                              ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                      Color(0xff9BD886),
                                    ), // Replace with your color
                                  ),
                                  onPressed: () {
                                    context.pop();

                                    context.push("/addNews");
                                  },
                                  child: Text("News",
                                      style: AppTypography.buttonText
                                          .copyWith(fontSize: 16)))
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.jacarta,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      size: 28,
                      Icons.add,
                      color: AppPalette.light_green,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ListView _listBuilderEvents(List<EventModel> upcomingEvents) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: upcomingEvents.length,
      itemBuilder: (context, index) {
        final event = upcomingEvents[index];
        return _eventTile(event);
      },
    );
  }

  ListView _listBuilderNews(List<NewsModel> newsList) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: newsList.length,
      itemBuilder: (context, index) {
        final news = newsList[index];
        return _newsTile(news);
      },
    );
  }

  ListView _listBuilderSelectedDay(List<EventModel> selectedDayEvents) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: selectedDayEvents.length,
      itemBuilder: (context, index) {
        final event = selectedDayEvents[index];
        return _eventTile(event);
      },
    );
  }

  String _shortenHeadline(String? headline, int maxLength) {
    if (headline == null || headline.isEmpty) {
      return 'No Title';
    }
    if (headline.length > maxLength) {
      return headline.substring(0, maxLength) + '...';
    }
    return headline;
  }

  Widget _newsTile(NewsModel news) {
    // Implementation of your news tile, similar to _eventTile...
    // resize news.headline based on its length
    String resizedHeadline = _shortenHeadline(news.headline, 23);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          context.push('/selectedNews', extra: news);
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
              color: Color(0xff875FC0),
              borderRadius: BorderRadius.all(Radius.circular(20))),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12, left: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    resizedHeadline,
                    style: AppTypography.calendarDays
                        .copyWith(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    "- ${news.author}",
                    style: AppTypography.calendarDays
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w200),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget tabContainers(BuildContext context, CalendarState state) {
    return Row(
      children: [
        _tabContainer("Upcoming", 1),
        _tabContainer("News", 2),
        _tabContainer("${state.selectedDay.month}.${state.selectedDay.day}", 3),
      ],
    );
  }

  Widget _tabContainer(String text, int index) {
    return InkWell(
      onTap: () {
        chooseTab(index);
      },
      child: Container(
        height: 100,
        padding: EdgeInsets.only(top: 10, bottom: 4, right: 8, left: 8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: tabIndex == index ? AppPalette.jacarta : Colors.transparent),
        child: Text(
          text,
          style: AppTypography.eventsWidgetText.copyWith(
              color: tabIndex == index
                  ? AppPalette.light_green
                  : const Color.fromARGB(155, 255, 255, 255)),
        ),
      ),
    );
  }
}
