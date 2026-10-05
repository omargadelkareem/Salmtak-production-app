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
  final effectiveRadius = borderRadius ?? BorderRadius.circular(24);
  final value = photoUrl.trim();

  if (value.startsWith('data:image')) {
    try {
      final Uint8List bytes = base64Decode(value.split(',').last);
      return ClipRRect(
        borderRadius: effectiveRadius,
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(width, height),
        ),
      );
    } catch (_) {
      return _fallback(width, height, radius: effectiveRadius);
    }
  }

  const fallbackUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop';

  return ClipRRect(
    borderRadius: effectiveRadius,
    child: CachedNetworkImage(
      imageUrl: value.isNotEmpty ? value : fallbackUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(width, height),
    ),
  );
}

Widget _fallback(double width, double height, {BorderRadius? radius}) {
  final child = Container(
    width: width,
    height: height,
    color: Colors.grey.shade200,
    alignment: Alignment.center,
    child: Icon(Icons.person, size: width * .55, color: Colors.grey.shade600),
  );
  return radius == null ? child : ClipRRect(borderRadius: radius, child: child);
}
