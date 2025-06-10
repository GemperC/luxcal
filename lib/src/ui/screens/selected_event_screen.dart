import 'dart:io';
import 'dart:typed_data';
import 'package:LuxCal/core/theme/pallette.dart';
import 'package:LuxCal/core/theme/typography.dart';
import 'package:LuxCal/src/blocs/calendar/calendar_bloc.dart';
import 'package:LuxCal/src/models/event_model.dart';
import 'package:LuxCal/src/ui/widgets/custom_scaffold.dart';
import 'package:LuxCal/src/ui/widgets/elevated_container_card.dart';
import 'package:LuxCal/src/ui/widgets/event_fields_widget.dart';
import 'package:LuxCal/src/ui/widgets/spacer.dart';
import 'package:LuxCal/src/utils/auth_utils.dart';
import 'package:LuxCal/src/utils/screen_size.dart';
import 'package:LuxCal/src/utils/upload_images.dart';
import 'package:LuxCal/src/utils/validators.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class SelectedEventScreen extends StatefulWidget {
  final EventModel eventModel;
  const SelectedEventScreen({super.key, required this.eventModel});

  @override
  State<SelectedEventScreen> createState() => _SelectedEventScreenState();
}

class _SelectedEventScreenState extends State<SelectedEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController titleController;
  late TextEditingController locationController;
  late TextEditingController descriptionController;
  late String autherName;
  late String autherNickname;
  DateTime? startDate;
  DateTime? endDate;
  Color backgroundColor = Colors.red;
  Color fieldColor = Colors.red;
  XFile? pickedImage;
  Uint8List? _imageBytes; // For cross-platform preview on Web

  @override
  void initState() {
    titleController =
        TextEditingController(text: widget.eventModel.title ?? "");
    locationController =
        TextEditingController(text: widget.eventModel.location ?? "");
    descriptionController =
        TextEditingController(text: widget.eventModel.description ?? "");
    autherName = widget.eventModel.authorName ?? "";
    autherNickname = widget.eventModel.authorNickname ?? "";
    startDate = widget.eventModel.startDate;
    endDate = widget.eventModel.endDate;
    backgroundColor = widget.eventModel.color!;
    fieldColor = getfieldColor(backgroundColor);
    super.initState();
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

  bool isAuther() {
    if (kIsWeb) {
      return true;
    } else {
      if (AuthUtils.isAppAdmin) {
        return true;
      } else {
        return AuthUtils.currentUserId == widget.eventModel.authorId;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              _buttonrow(context),
              Padding(
                padding: const EdgeInsets.only(top: 35.0),
                child: Column(
                  children: [
                    IgnorePointer(
                      ignoring: !isAuther(),
                      child: Column(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _header(widget.eventModel.title!),
                          ),
                          spacer(20),
                          _form(),
                          spacer(20),
                        ],
                      ),
                    ),
                    _imagePickerButton(), // Button to pick/upload photos
                    spacer(20),
                    _viewGalleryButton(), // Button to view gallery
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() => Padding(
        padding: const EdgeInsets.only(right: 10, left: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isAuther() ? _titleFromField() : _autherFromField(),
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

  Widget _datesFromField() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IntrinsicWidth(
                child: ElevatedContainerCard(
                  height: context.height * 0.1,
                  color: fieldColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () async {
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
                                    ? "${startDate!.day}/${startDate!.month}/${startDate!.year}"
                                    : "DD/MM/YY",
                                style: AppTypography.textFieldText
                                    .copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        spacer(10),
                        InkWell(
                          onTap: () async {
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
                                    ? "${endDate!.day}/${endDate!.month}/${endDate!.year}"
                                    : "DD/MM/YY",
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
                  color: fieldColor,
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
                                startDate = startDate!.copyWith(
                                  hour: time.hour,
                                  minute: time.minute,
                                );
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
                                endDate = endDate!.copyWith(
                                  hour: time.hour,
                                  minute: time.minute,
                                );
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
        ]);
  }

  Widget _titleFromField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          spacer(10),
          EventFieldsTextfield(
            textField: TextField(
              controller: titleController,
              keyboardType: TextInputType.name,
              decoration: InputDecoration(fillColor: fieldColor, filled: true),
            ),
            validator: (value) => Validators.eventTitleValidator(value),
          ),
        ],
      );

  Widget _autherFromField() => Stack(
        children: [
          spacer(10),
          EventFieldsTextfield(
            textField: TextField(
              keyboardType: TextInputType.name,
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: "",
                fillColor: fieldColor,
                filled: true,
              ),
            ),
            validator: (value) => Validators.eventTitleValidator(value),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0, left: 12),
            child: Row(
              children: [
                Text(
                  "$autherNickname",
                  style: AppTypography.textFieldText,
                ),
                spacerWidth(20),
                Text(
                  "$autherName",
                  style: AppTypography.textFieldTextLight,
                ),
              ],
            ),
          ),
        ],
      );

  Widget _locationFromField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          spacer(10),
          Container(
            width: context.width * 0.94,
            child: EventFieldsTextfield(
              textField: TextField(
                controller: locationController,
                keyboardType: TextInputType.name,
                decoration: InputDecoration(fillColor: fieldColor),
              ),
            ),
          ),
        ],
      );

  Widget _descriptionFromField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show the event's current image if no new image is picked.
          if (widget.eventModel.imageUrl != null && pickedImage == null)
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.network(widget.eventModel.imageUrl!),
            ),
          // If a new image is picked, show its preview.
          if (pickedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: kIsWeb && _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.contain)
                  : Image.file(File(pickedImage!.path), fit: BoxFit.contain),
            ),
          spacer(10),
          Stack(
            children: [
              SizedBox(
                width: context.width * 0.94,
                child: IntrinsicHeight(
                  child: EventFieldsTextfield(
                    textField: TextField(
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      controller: descriptionController,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(fillColor: fieldColor),
                    ),
                  ),
                ),
              ),
              if (isAuther())
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
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _imagePickerButton() {
    return isAuther()
        ? ElevatedButton(
            onPressed: () async {
              final ImagePicker _picker = ImagePicker();
              final List<XFile>? images = await _picker.pickMultiImage();
              if (images != null && images.isNotEmpty) {
                await uploadImagesToFirebase(widget.eventModel.id, images);
              }
            },
            child: const Text("Add Photos"),
          )
        : Container();
  }


  Widget _viewGalleryButton() {
    bool isMaker = false;
    if (AuthUtils.isAppAdmin) {
      isMaker = true;
    } else {
      isMaker = AuthUtils.currentUserId == widget.eventModel.authorId;
    }
    return ElevatedButton(
      onPressed: () {
        print(widget.eventModel.id);
        context.push('/event/${widget.eventModel.id}/gallery?isMaker=$isMaker');
      },
      child: const Text("View Gallery"),
    );
  }

  Text _header(String title) {
    return Text(
      title,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                final updatedEvent = widget.eventModel.copyWith(
                  title: titleController.text,
                  location: locationController.text,
                  description: descriptionController.text,
                  startDate: startDate,
                  endDate: endDate,
                );
                if (pickedImage != null) {
                  BlocProvider.of<CalendarBloc>(context).add(UpdateEvent(
                      updatedEvent: updatedEvent, pickedImage: pickedImage));
                } else {
                  BlocProvider.of<CalendarBloc>(context)
                      .add(UpdateEvent(updatedEvent: updatedEvent));
                }
                context.pop();
              },
              child: const Icon(
                Icons.arrow_back,
                color: Colors.black,
                size: 30,
              ),
            ),
            if (isAuther())
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: AppPalette.jacarta,
                        title: Center(
                          child: Text(
                            "Delete Event?",
                            style:
                                AppTypography.buttonText.copyWith(fontSize: 24),
                          ),
                        ),
                        content: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(
                                  const Color.fromARGB(255, 170, 20, 0),
                                ),
                              ),
                              onPressed: () {
                                context.read<CalendarBloc>().add(
                                    DeleteEvent(eventId: widget.eventModel.id));
                                context.pop();
                                context.pop();
                              },
                              child: Text(
                                "Yes",
                                style: AppTypography.buttonText
                                    .copyWith(fontSize: 16),
                              ),
                            ),
                            spacerWidth(20),
                            ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(
                                  const Color.fromARGB(255, 134, 143, 216),
                                ),
                              ),
                              onPressed: () {
                                context.pop();
                              },
                              child: Text(
                                "No",
                                style: AppTypography.buttonText
                                    .copyWith(fontSize: 16),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
                child: const Icon(
                  Icons.delete,
                  color: Colors.black,
                  size: 30,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
