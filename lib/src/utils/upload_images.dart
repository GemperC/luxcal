import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

Future<void> uploadImagesToFirebase(String eventId, List<XFile> images) async {
  try {
    String? firstImageUrl; // Track the first image to set as main image

    for (int i = 0; i < images.length; i++) {
      var image = images[i];
      String fileName = path.basename(image.path);
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('event_albums/$eventId/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        // On Web, use putData since File(image.path) doesn't work
        final bytes = await image.readAsBytes();
        uploadTask = storageRef.putData(bytes);
      } else {
        // On mobile/desktop, use putFile
        uploadTask = storageRef.putFile(File(image.path));
      }

      // Monitor the upload progress.
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
            'Progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100} %');
      }, onError: (e) {
        print(uploadTask.snapshot);
        if (e.code == 'permission-denied') {
          print('User does not have permission to upload to this reference.');
        }
      });

      // Wait until the upload completes.
      await uploadTask;

      // Get the download URL and store it in Firestore.
      final downloadURL = await storageRef.getDownloadURL();
      print('Download URL: $downloadURL');

      // Store the first image URL to update the main event
      if (i == 0) {
        firstImageUrl = downloadURL;
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('images')
          .add({
        'path': storageRef.fullPath,
        'url': downloadURL,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isMain': i == 0, // Mark the first image as main
      });
    }

    // Update the main event with the first image URL
    if (firstImageUrl != null) {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({'imageUrl': firstImageUrl});
      print('Updated event with main image URL: $firstImageUrl');
    }
  } catch (e) {
    print('Error uploading images: $e');
  }
}

// Similar fix for news images
Future<void> uploadNewsImagesToFirebase(
    String newsId, List<XFile> images) async {
  try {
    String? firstImageUrl; // Track the first image to set as main image

    for (int i = 0; i < images.length; i++) {
      var image = images[i];
      String fileName = path.basename(image.path);
      Reference storageRef =
          FirebaseStorage.instance.ref().child('news_albums/$newsId/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        // Read as bytes and use putData for Web
        final data = await image.readAsBytes();
        uploadTask = storageRef.putData(data);
      } else {
        // Use putFile for mobile/desktop
        uploadTask = storageRef.putFile(File(image.path));
      }

      // Monitor the upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
            'Progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100} %');
      }, onError: (e) {
        print(uploadTask.snapshot);
        if (e.code == 'permission-denied') {
          print('User does not have permission to upload to this reference.');
        }
      });

      // Wait until the upload completes
      await uploadTask;

      // Get the download URL
      final downloadURL = await storageRef.getDownloadURL();
      print('Download URL: $downloadURL');

      // Store the first image URL to update the main news item
      if (i == 0) {
        firstImageUrl = downloadURL;
      }

      // Save the download URL and path to Firestore
      await FirebaseFirestore.instance
          .collection('news')
          .doc(newsId)
          .collection('images')
          .add({
        'path': storageRef.fullPath,
        'url': downloadURL,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isMain': i == 0, // Mark the first image as main
      });
    }

    // Update the main news item with the first image URL
    if (firstImageUrl != null) {
      await FirebaseFirestore.instance
          .collection('news')
          .doc(newsId)
          .update({'imageUrl': firstImageUrl});
      print('Updated news with main image URL: $firstImageUrl');
    }
  } catch (e) {
    print('Error uploading images: $e');
  }
}
