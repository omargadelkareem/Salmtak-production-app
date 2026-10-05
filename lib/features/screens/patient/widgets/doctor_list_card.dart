import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class DoctorListCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onOpen;
  final bool highlightNearby;

  /// Optional external builder (لو عندك هيلبر جاهز زي buildDoctorImage)
  final Widget Function(
    String photoUrl, {
    double width,
    double height,
    BorderRadius? borderRadius,
  })? buildDoctorImage;

  const DoctorListCard({
    required this.doctor,
    required this.onOpen,
    this.highlightNearby = false,
    this.buildDoctorImage,
  });

  /// ✅ Internal safe image widget (Base64 OR URL)
  Widget _safeDoctorImage(
    String photoUrl, {
    double width = 82,
    double height = 82,
    BorderRadius? borderRadius,
  }) {
    borderRadius ??= BorderRadius.circular(18);

    // Base64 case: data:image/...;base64,XXXX
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                width: width,
                height: height,
                color: Colors.grey.shade200,
                child: Icon(Icons.person,
                    size: width * 0.55, color: Colors.grey.shade600),
              );
            },
          ),
        );
      } catch (_) {
        // fallback below
      }
    }

    const fallbackUrl =
        'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop';

    // URL case
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: photoUrl.isNotEmpty ? photoUrl : fallbackUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(Icons.person,
              size: width * 0.55, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final photoUrl = (doctor['photoUrl'] ?? '').toString();
    final name = (doctor['name'] ?? 'دكتور').toString();
    final spec = (doctor['specialization'] ?? 'غير محدد').toString();

    final governorate = (doctor['governorate'] ?? 'غير محدد').toString();
    final center = (doctor['center'] ?? '').toString();
    final locationText =
        center.trim().isEmpty ? governorate : '$governorate - $center';

    final priceRaw = doctor['price'];
    final int price =
        (priceRaw is num) ? priceRaw.toInt() : int.tryParse('$priceRaw') ?? 300;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlightNearby
                  ? const Color(0xFF1E3A8A).withOpacity(0.25)
                  : cs.outlineVariant.withOpacity(0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  // ✅ SAFE IMAGE (Base64 / URL)
                  (buildDoctorImage != null)
                      ? buildDoctorImage!(
                          photoUrl,
                          width: 82,
                          height: 82,
                          borderRadius: BorderRadius.circular(18),
                        )
                      : _safeDoctorImage(
                          photoUrl,
                          width: 82,
                          height: 82,
                          borderRadius: BorderRadius.circular(18),
                        ),

                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (highlightNearby)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    const Color(0xFF1E3A8A).withOpacity(0.20),
                              ),
                            ),
                            child: const Text(
                              'قريب',
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_hospital_outlined,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.70),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.22)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$price جنيه',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Color(0xFF1E3A8A),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
