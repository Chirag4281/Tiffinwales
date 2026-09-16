import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../subscription/subscription_management_screen.dart';

class ManagerSubscriptionsTab extends StatelessWidget {
  final String locationName;
  final String email;

  const ManagerSubscriptionsTab({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return SubscriptionManagementScreen(
      locationName: locationName,
      email: email,
    );
  }
}