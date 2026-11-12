import 'package:flutter/material.dart';

class AppStyles {
  static const Color primaryColor = Color.fromARGB(255, 144, 4, 165);
  static const Color backgroundColor = Color.fromARGB(255, 255, 255, 255);
  static const Color textColor = Color.fromARGB(255, 0, 0, 0);

  static const TextStyle headingText = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
  );
}
