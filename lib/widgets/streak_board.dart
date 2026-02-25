import 'package:flutter/material.dart';

class StreakBoard extends StatelessWidget {
  const StreakBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.blueGrey[100],
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.blueGrey),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Streaks',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Max: 0',
              style: TextStyle(color: Colors.blueGrey),
            ),
            Text(
              'Current: 0',
              style: TextStyle(color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }
}
