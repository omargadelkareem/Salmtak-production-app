import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const String _fallbackDoctorImage =
    'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop';

Widget buildDoctorImage(
  String? photoUrl, {
  double width = 110,
  double height = 110,
  BorderRadius? borderRadius,
  BoxFit fit = BoxFit.cover,
}) {
  final radius = borderRadius ?? BorderRadius.circular(24);
  final value = (photoUrl ?? '').trim();

  Widget placeholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEFF3F5),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: width * 0.48,
        color: Colors.grey.shade500,
      ),
    );
  }

  if (value.startsWith('data:image')) {
    try {
      final String encoded = value.split(',').last;
      final Uint8List bytes = base64Decode(encoded);

      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder(),
        ),
      );
    } catch (_) {
      return ClipRRect(borderRadius: radius, child: placeholder());
    }
  }

  return ClipRRect(
    borderRadius: radius,
    child: CachedNetworkImage(
      imageUrl: value.isEmpty ? _fallbackDoctorImage : value,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: const Color(0xFFEFF3F5),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => placeholder(),
    ),
  );
}
