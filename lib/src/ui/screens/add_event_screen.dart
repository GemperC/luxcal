import 'dart:io';
import 'dart:typed_data';

import 'package:LuxCal/core/theme/pallette.dart';
import 'package:LuxCal/core/theme/typography.dart';
import 'package:LuxCal/main.dart';
import 'package:LuxCal/src/blocs/calendar/calendar_bloc.dart';
import 'package:LuxCal/src/models/event_model.dart';
import 'package:LuxCal/src/ui/screens/splash_screen.dart';
import 'package:LuxCal/src/ui/widgets/custom_scaffold.dart';
import 'package:LuxCal/src/ui/widgets/elevated_container_card.dart';
import 'package:LuxCal/src/ui/widgets/event_fields_widget.dart';
import 'package:LuxCal/src/ui/widgets/spacer.dart';
import 'package:LuxCal/src/ui/widgets/textfield.dart';
import 'package:LuxCal/src/utils/auth_utils.dart';
import 'package:LuxCal/src/utils/event_colors.dart';
import 'package:LuxCal/src/utils/messenger.dart';
import 'package:LuxCal/src/utils/screen_size.dart';
import 'package:LuxCal/src/utils/upload_images.dart';
import 'package:LuxCal/src/utils/validators.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_hebrew_date_picker/cupertino_hebrew_date_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  String recurrence = "One Time";
  bool isHebrew = false;
  final List<String> recurrenceOptions = [
    "One Time",
    "Every Day",
    "Once a Week",
    "Once a Month",
    "Once a Year"
  ];
  Color? pickedColor;
  XFile? pickedImage;
  Uint8List? _imageBytes; // Used for web preview

  @override
  void initState() {
    super.initState();
    // Set a default color (assuming customColors is defined in your event_colors)
    pickedColor = customColors[0];
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Color getfieldColor(Color backgroundColor) {
    int r = (backgroundColor.red + 18 <= 255) ? backgroundColor.red + 18 : 255;
    int g =
        (backgroundColor.green + 18 <= 255) ? backgroundColor.green + 18 : 255;
    int b =
        (backgroundColor.blue + 18 <= 255) ? backgroundColor.blue + 18 : 255;
    return Color.fromARGB(backgroundColor.alpha, r, g, b);
  }

  // Toggle between Hebrew and Gregorian formats.
  Widget _hebrewDatePicker() {
    return TextButton(
      onPressed: () {
        setState(() {
          isHebrew = !isHebrew;
        });
      },
      child: Text(
        isHebrew ? "Hebrew" : "Gregorian",
        style: const TextStyle(
            fontSize: 16, color: Color.fromARGB(255, 255, 28, 217)),
      ),
    );
  }

  void _onButtonPress() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    if (startDate == null || endDate == null) {
      Utils.showSnackBar("Please select a date and time");
      return;
    }
    if (startDate!.isAfter(endDate!)) {
      Utils.showSnackBar("Invalid start and end dates");
      return;
    }

    _showLoadingDialog();

    final EventModel newEvent = EventModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: titleController.text,
      description: descriptionController.text,
      startDate: startDate!,
      endDate: endDate!,
      color: pickedColor,
      location: locationController.text,
      authorName: AuthUtils.currentUser.fullName!,
      authorNickname: AuthUtils.currentUser.nickName!,
      authorId: AuthUtils.currentUserId,
      recurrence: recurrence,
      hebrewFormat: isHebrew,
    );

    try {
      // Add the event.
      context.read<CalendarBloc>().add(AddEvent(newEvent, pickedImage));

      // If a thumbnail is picked, upload it.
      if (pickedImage != null) {
        await uploadImagesToFirebase(newEvent.id, [pickedImage!]);
      }

      Navigator.pop(context); // Dismiss loading dialog.
      context.pop(); // Navigate back.
      RestartWidget.restartApp(context);
      context.go('/calendar');
    } catch (e) {
      Navigator.pop(context);
      Utils.showSnackBar("Error: $e");
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss on tap outside.
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Processing... Please wait"),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // The entire page is scrollable.
    return CustomScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              _buttonrow(context),
              Column(
                children: [
                  _header(),
                  spacer(20),
                  _form(),
                  spacer(20),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: const Color.fromARGB(255, 255, 135, 61),
        shape: const CircleBorder(),
        child:
            const Icon(FontAwesomeIcons.check, size: 60, color: Colors.white),
        onPressed: _onButtonPress,
      ),
    );
  }

  Widget _form() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _titleFromField(),
                  spacerWidth(10),
                  _colorFormField(),
                ],
              ),
              spacer(20),
              _datesFromField(),
              spacer(20),
              _locationFromField(),
              spacer(20),
              _descriptionFromField(),
            ],
          ),
        ),
      );

  Widget _titleFromField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text("Event Title:", style: AppTypography.textFieldText),
          ),
          spacer(10),
          Container(
            width: context.width * 0.8,
            child: EventFieldsTextfield(
              textField: TextField(
                controller: titleController,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(labelText: "Event Title"),
              ),
              validator: (value) => Validators.eventTitleValidator(value),
            ),
          ),
        ],
      );

  Widget _colorFormField() {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0),
      child: Container(
        height: 45,
        width: 45,
        padding: const EdgeInsets.all(1.5),
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: AppPalette.jacarta,
                  content: Padding(
                    padding: const EdgeInsets.only(left: 0.0),
                    child: MaterialColorPicker(
                      allowShades: false,
                      selectedColor: pickedColor,
                      colors: customColors,
                      shrinkWrap: true,
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      onMainColorChange: (colorSwatch) {
                        final int colorValue = colorSwatch!.value;
                        setState(() => pickedColor = Color(colorValue));
                        context.pop();
                      },
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            decoration:
                BoxDecoration(color: pickedColor, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _datesFromField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Row(
          children: [
            Text(
              "Format:",
              style: AppTypography.textFieldText.copyWith(fontSize: 16),
            ),
            _hebrewDatePicker(),
          ],
        ),
      ),
      spacer(10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IntrinsicWidth(
            child: ElevatedContainerCard(
              height: context.height * 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () async {
                        if (isHebrew) {
                          showHebrewCupertinoDatePicker(
                            confirmText: "Confirm",
                            context: context,
                            onDateChanged: (dateTime) => print(dateTime),
                            onConfirm: (dateTime) {
                              if (dateTime != null) {
                                setState(() {
                                  startDate = dateTime;
                                });
                              }
                            },
                          );
                        } else {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              startDate = date;
                            });
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            "Start Date:   ",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                          Text(
                            startDate != null
                                ? "${startDate!.month}/${startDate!.day}/${startDate!.year}"
                                : "MM/DD/YY",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    spacer(10),
                    InkWell(
                      onTap: () async {
                        if (isHebrew) {
                          showHebrewCupertinoDatePicker(
                            confirmText: "Confirm",
                            context: context,
                            onDateChanged: (dateTime) => print(dateTime),
                            onConfirm: (dateTime) {
                              if (dateTime != null) {
                                setState(() {
                                  endDate = dateTime;
                                });
                              }
                            },
                          );
                        } else {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              endDate = date;
                            });
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            "End Date:   ",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                          Text(
                            endDate != null
                                ? "${endDate!.month}/${endDate!.day}/${endDate!.year}"
                                : "MM/DD/YY",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          spacerWidth(10),
          IntrinsicWidth(
            child: ElevatedContainerCard(
              height: context.height * 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now());
                        if (time != null) {
                          setState(() {
                            startDate = startDate?.copyWith(
                                hour: time.hour, minute: time.minute);
                          });
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            "Start Time:   ",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                          Text(
                            startDate != null
                                ? "${startDate!.hour}:${startDate!.minute}"
                                : "hh:mm",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    spacer(10),
                    InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now());
                        if (time != null) {
                          setState(() {
                            endDate = endDate?.copyWith(
                                hour: time.hour, minute: time.minute);
                          });
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            "End Time:   ",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                          Text(
                            endDate != null
                                ? "${endDate!.hour}:${endDate!.minute}"
                                : "hh:mm",
                            style: AppTypography.textFieldText
                                .copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      spacer(20),
      Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "Recurrence:",
              style: AppTypography.textFieldText.copyWith(fontSize: 16),
            ),
          ),
          spacerWidth(10),
          ElevatedContainerCard(
            height: 50,
            width: 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButton<String>(
                isExpanded: true,
                value: recurrence,
                items: recurrenceOptions.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    recurrence = newValue!;
                  });
                },
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
                dropdownColor: AppPalette.jacarta,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.blue,
                ),
                iconSize: 30,
                underline: Container(
                  height: 2,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
      spacer(10),
    ]);
  }

  Widget _locationFromField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text(
              "Location:",
              style: AppTypography.textFieldText,
            ),
          ),
          spacer(10),
          Container(
            width: context.width * 0.94,
            child: EventFieldsTextfield(
              textField: TextField(
                controller: locationController,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(labelText: "Location"),
              ),
            ),
          ),
        ],
      );

  Widget _descriptionFromField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display only the picked image preview.
          if (pickedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: kIsWeb && _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : Image.file(File(pickedImage!.path), fit: BoxFit.cover),
            ),
          spacer(10),
          Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text(
              "Description:",
              style: AppTypography.textFieldText,
            ),
          ),
          spacer(10),
          Stack(
            children: [
              Container(
                width: context.width * 0.94,
                child: IntrinsicHeight(
                  child: EventFieldsTextfield(
                    textField: TextField(
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      controller: descriptionController,
                      keyboardType: TextInputType.multiline,
                      decoration:
                          const InputDecoration(labelText: "Description"),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.95, 1),
                child: IconButton(
                  onPressed: () async {
                    final ImagePicker _picker = ImagePicker();
                    final XFile? image =
                        await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      if (kIsWeb) {
                        final bytes = await image.readAsBytes();
                        setState(() {
                          pickedImage = image;
                          _imageBytes = bytes;
                        });
                      } else {
                        setState(() {
                          pickedImage = image;
                        });
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.image,
                    color: Color.fromARGB(211, 7, 197, 255),
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _viewGalleryButton() {
    // For Add Event screen, you may not have an existing gallery.
    // You can hide this button or adjust its behavior as needed.
    return Container();
  }

  Text _header() {
    return Text(
      'Create Event',
      style: GoogleFonts.getFont(
        "Poppins",
        fontSize: 35,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buttonrow(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, right: 10, left: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                context.pop();
              },
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xffFCB833),
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
