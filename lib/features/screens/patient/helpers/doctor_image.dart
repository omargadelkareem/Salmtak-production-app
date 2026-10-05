import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

Widget buildDoctorImage(
  String photoUrl, {
  double width = 110,
  double height = 110,
  BorderRadius? borderRadius,
}) {
  borderRadius ??= BorderRadius.circular(24);

  if (photoUrl.startsWith('data:image')) {
    try {
      final String base64String = photoUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: Icon(Icons.person,
                  size: width * 0.6, color: Colors.grey.shade600),
            );
          },
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('خطأ في تحويل Base64: $e');
    }
  }

  return ClipRRect(
    borderRadius: borderRadius,
    child: CachedNetworkImage(
      imageUrl: photoUrl.isNotEmpty
          ? photoUrl
          : 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop',
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child:
            Icon(Icons.person, size: width * 0.6, color: Colors.grey.shade600),
      ),
    ),
  );
}
