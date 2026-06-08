import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/location_service.dart';
import 'home_screen.dart';
import 'chat_screen.dart';

class MainNav extends StatefulWidget {
  final LocationResult location;
  final Map<String, List<Place>> initialPlaces;

  const MainNav({
    super.key,
    required this.location,
    required this.initialPlaces,
  });

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(location: widget.location, places: widget.initialPlaces),
      ChatScreen(location: widget.location),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: '데이트 상담',
          ),
        ],
      ),
    );
  }
}
