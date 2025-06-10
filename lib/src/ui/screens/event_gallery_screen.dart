import 'package:LuxCal/src/blocs/calendar/calendar_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/download_all_zip.dart';
import '../../utils/download_utils.dart'; // <-- Import the new ZIP logic

class EventGalleryScreen extends StatefulWidget {
  final String eventId;
  final bool isMaker;
  const EventGalleryScreen({
    super.key,
    required this.eventId,
    required this.isMaker,
  });

  @override
  _EventGalleryScreenState createState() => _EventGalleryScreenState();
}

class _EventGalleryScreenState extends State<EventGalleryScreen> {
  bool _isZipping = false;

  /// Fetch all image URLs for the event from Firestore.
  Future<List<String>> _fetchImageUrls() async {
    final imagesRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('images');

    final querySnapshot = await imagesRef.get();
    final imageUrls = <String>[];
    for (var doc in querySnapshot.docs) {
      imageUrls.add(doc['url']);
    }
    return imageUrls;
  }

  /// Zip and download all images as a single file.
  Future<void> _downloadAllAsZip() async {
    try {
      setState(() {
        _isZipping = true;
      });
      final imageUrls = await _fetchImageUrls();
      if (imageUrls.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No images found')));
        return;
      }

      // Use the cross-platform ZIP approach.
      await downloadAllImagesAsZip(imageUrls, zipName: 'event_images.zip');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ZIP download complete')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading ZIP: $e')),
      );
    } finally {
      setState(() {
        _isZipping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadAllAsZip,
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<String>>(
            future: _fetchImageUrls(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Center(child: Text('Error loading images'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No images found'));
              } else {
                final imageUrls = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // Three columns
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 1.0, // Square items
                  ),
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    final imageUrl = imageUrls[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullImageScreen(
                              imageUrl: imageUrl,
                              isMaker: widget.isMaker,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Text(
                                  'Failed to load',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
          if (_isZipping)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class FullImageScreen extends StatelessWidget {
  final String imageUrl;
  final bool isMaker;
  const FullImageScreen({
    super.key,
    required this.imageUrl,
    required this.isMaker,
  });

  /// Deletes the image by finding its Firestore document and removing it along with the storage file.
  Future<void> _deleteImage(BuildContext context) async {
    try {
      // Find the image document in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('images')
          .where('url', isEqualTo: imageUrl)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docSnapshot = querySnapshot.docs.first;
        final imagePath = docSnapshot['path'];
        final isMain = docSnapshot.data().containsKey('isMain')
            ? docSnapshot['isMain']
            : false;

        // Get the parent collection reference to find if this is an event or news image
        final parentPath = docSnapshot.reference.parent.parent?.path;

        // Delete from storage
        await FirebaseStorage.instance.ref(imagePath).delete();

        // Delete from Firestore
        await docSnapshot.reference.delete();

        // If this was the main image, update the parent document
        if (isMain && parentPath != null) {
          // Find the next image to set as main
          final remainingImages = await docSnapshot.reference.parent.get();

          if (remainingImages.docs.isNotEmpty) {
            // Set the first remaining image as the new main image
            final newMainImage = remainingImages.docs.first;
            final newMainUrl = newMainImage['url'];

            // Update the main image in parent document
            await docSnapshot.reference.parent.parent!
                .update({'imageUrl': newMainUrl});

            // Mark the new image as main
            await newMainImage.reference.update({'isMain': true});
          } else {
            // No images left, remove the main image URL
            await docSnapshot.reference.parent.parent!
                .update({'imageUrl': null});
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting image: $e')),
      );
    }
  }

  static void refreshCalendarAfterPhotoOperation(BuildContext context) {
    // Trigger calendar refresh
    context.read<CalendarBloc>().add(InilaizeCalendar());
  }

  /// Downloads a single image (currently placeholder).
  Future<void> _downloadImage(BuildContext context) async {
    try {
      final fileName = imageUrl.split('/').last.split('?').first;
      await saveNetworkImage(imageUrl, fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to gallery')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadImage(context),
          ),
          if (isMaker)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Image'),
                    content: const Text(
                        'Are you sure you want to delete this image?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _deleteImage(context);
                }
              },
            ),
        ],
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: Text(
                  'Failed to load',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
