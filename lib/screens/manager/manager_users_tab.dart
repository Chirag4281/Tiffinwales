import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiffinwales/screens/user_subscriptions_screen.dart';

class ManagerUsersTab extends StatelessWidget {
  final String locationName;
  final String email;

  const ManagerUsersTab({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return UserSubscriptionsScreen(
      locationName: locationName,
      email: email,
    );
  }
}