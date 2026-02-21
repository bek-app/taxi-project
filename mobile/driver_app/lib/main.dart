import 'package:flutter/material.dart';

void main() {
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Driver MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFAA4A17)),
        useMaterial3: true,
      ),
      home: const DriverHomePage(),
    );
  }
}

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool _online = false;
  String _status = 'IDLE';

  void _toggleOnline(bool value) {
    setState(() {
      _online = value;
      if (!_online) {
        _status = 'IDLE';
      }
    });
  }

  void _acceptRide() {
    setState(() {
      _status = 'DRIVER_ASSIGNED';
    });
  }

  void _startRide() {
    setState(() {
      _status = 'IN_PROGRESS';
    });
  }

  void _completeRide() {
    setState(() {
      _status = 'COMPLETED';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver MVP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Driver online'),
              subtitle: const Text('Redis geo index + availability update'),
              value: _online,
              onChanged: _toggleOnline,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current order status'),
                    const SizedBox(height: 6),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _online ? _acceptRide : null,
                  child: const Text('Accept Ride'),
                ),
                FilledButton.tonal(
                  onPressed: _status == 'DRIVER_ASSIGNED' ? _startRide : null,
                  child: const Text('Start Ride'),
                ),
                OutlinedButton(
                  onPressed: _status == 'IN_PROGRESS' ? _completeRide : null,
                  child: const Text('Complete Ride'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Next step: backend endpoints + WebSocket with real lifecycle sync.',
            ),
          ],
        ),
      ),
    );
  }
}
