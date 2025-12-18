import 'package:flutter/material.dart';

class IconHelper {
  static IconData fromString(String? name) {
    switch (name) {
      case 'man':
        return Icons.man;
      case 'woman':
        return Icons.woman;
      case 'boy':
        return Icons.boy;
      case 'girl':
        return Icons.girl;
      case 'person_outline':
        return Icons.person_outline;
      case 'sports_motorsports':
        return Icons.sports_motorsports;
      case 'directions_car':
        return Icons.directions_car;
      case 'two_wheeler':
        return Icons.two_wheeler;
      case 'engineering':
        return Icons.engineering;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'military_tech':
        return Icons.military_tech;
      default:
        return Icons.person;
    }
  }
}
