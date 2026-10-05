import 'package:flutter/material.dart';

class SimpleBottomNavBar extends StatelessWidget {
  const SimpleBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.userName,
    this.avatar,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final String userName;
  final ImageProvider? avatar;

  static const Color primary = Color(0xff0F766E);
  static const Color textColor = Color(0xff0F172A);
  static const Color grey = Color(0xff94A3B8);

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        "icon": Icons.calendar_month_outlined,
        "active": Icons.calendar_month,
        "label": "مواعيدي"
      },
      {
        "icon": Icons.person_add_alt_outlined,
        "active": Icons.person_add_alt,
        "label": "رشح طبيبك"
      },
      {"icon": Icons.home_outlined, "active": Icons.home, "label": "الرئيسية"},
      {
        "icon": Icons.favorite_outline,
        "active": Icons.favorite,
        "label": "المفضلة"
      },
    ];

    return Container(
      margin: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 18,
      ),
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...List.generate(items.length, (index) {
            final selected = selectedIndex == index;

            return GestureDetector(
              onTap: () {
                onTap(index);
              },
              behavior: HitTestBehavior.translucent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 16 : 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xffE8F8F6) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? items[index]["active"] as IconData
                          : items[index]["icon"] as IconData,
                      color: selected ? primary : grey,
                      size: 25,
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? primary : grey,
                      ),
                      child: Text(
                        items[index]["label"] as String,
                      ),
                    )
                  ],
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              onTap(4);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: selectedIndex == 4 ? 2 : 1,
                  color: selectedIndex == 4 ? primary : Colors.grey.shade300,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xffE8F8F6),
                backgroundImage: avatar,
                child: avatar == null
                    ? Icon(
                        selectedIndex == 4
                            ? Icons.person
                            : Icons.person_outline,
                        size: 20,
                        color: primary,
                      )
                    : null,
              ),
            ),
          )
        ],
      ),
    );
  }
}
