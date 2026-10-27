import 'package:flutter/material.dart';
import 'provisioning_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only the official ESP BLE Provisioning page & workflow
    return const ProvisioningScreen();
  }
}
