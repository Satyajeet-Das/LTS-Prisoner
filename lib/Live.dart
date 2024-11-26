import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'PrisonerListPage.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Location Tracker',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: LocationTrackingScreen(),
//     );
//   }
// }

String apiUrl =
    'https://zn3lffjl-7000.inc1.devtunnels.ms';

class LocationTrackingScreen extends StatefulWidget {
  @override
  _LocationTrackingScreenState createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  late LocationTracker locationTracker;
  String _currentPosition = "Fetching precise location...";

  @override
  void initState() {
    super.initState();
    locationTracker = LocationTracker(
      onLocationUpdate: (String position) {
        setState(() {
          _currentPosition = position;
        });
      },
    );
    locationTracker.startTracking(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Location Tracker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on,
              color: Colors.teal,
              size: 60,
            ),
            SizedBox(height: 20),
            Text(
              "Your Current Location:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.teal.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.2),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                _currentPosition,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.teal.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  void dispose() {
    locationTracker.stopTracking();
    super.dispose();
  }
}

class LocationTracker {
  late IO.Socket socket;
  late String? trackingId;
  late int? prisonerId;
  late String? name;
  Position? lastPosition;
  final Function(String) onLocationUpdate;
  StreamSubscription<Position>? positionStream;

  LocationTracker({required this.onLocationUpdate}) {
    initSocket();
  }

  void initSocket() {
    socket = IO.io(apiUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      print('Connected to server');
    });

    socket.onDisconnect((_) {
      print('Disconnected from server');
    });
  }

  Future<void> startTracking(BuildContext context) async {
    await _initializeBackgroundExecution();
    trackingId = await _getOrCreateDeviceId();
    prisonerId = await _getOrCreatePrisonerId();
    name = await _getOrCreateName();

    print("Tracking ID: $trackingId");
    print("Prisoner ID: $prisonerId");
    print("Name: $name");

    // New Code: Check if IDs are missing and navigate accordingly
    if (prisonerId  == null || trackingId == null || name == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PrisonerListPage()),
      );
      return;  // Stop further execution if IDs are missing
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied.');
      return;
    } else if (permission == LocationPermission.denied) {
      print('Location permissions are denied.');
      return;
    }

    // Start listening to the position stream
    positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (lastPosition == null || _hasSignificantChange(position, lastPosition!)) {
        lastPosition = position;
        double latitude = position.latitude;
        double longitude = position.longitude;
        String currentLatLng = "Latitude: ${latitude.toStringAsPrecision(8)}, Longitude: ${longitude.toStringAsPrecision(8)}";

        print(currentLatLng);

        sendLocation(name, trackingId, latitude, longitude);
        onLocationUpdate(currentLatLng);
      }
    });
  }

  bool _hasSignificantChange(Position newPosition, Position oldPosition) {
    const double threshold = 0.00001;
    return (newPosition.latitude - oldPosition.latitude).abs() > threshold ||
        (newPosition.longitude - oldPosition.longitude).abs() > threshold;
  }

  Future<void> _initializeBackgroundExecution() async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'Location Tracking',
      notificationText: 'Location tracking is active in the background',
      notificationImportance: AndroidNotificationImportance.normal,
    );

    bool hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
    if (hasPermissions) {
      await FlutterBackground.enableBackgroundExecution();
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('trackingId');
    if (id == null || id.isEmpty) {
      print("Tracking ID not found or empty");
      return "";  // Return an empty string if trackingId is not set
    }
    return id;
  }

  Future<int> _getOrCreatePrisonerId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int? id = prefs.getInt('prisonerId');
    if (id == null) {
      print("Prisoner ID not found or empty");
      return -1;  // Return an empty string if prisonerId is not set
    }
    return id;

  }

  Future<String> _getOrCreateName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('name');
    if (id == null) {
      print("Name not found or empty");
      return "";  // Return an empty string if prisonerId is not set
    }
    return id;

  }

  void sendLocation(String? name, String? trackingId, double latitude, double longitude) {
    if (socket.connected) {
      socket.emit("updateLocation", {
        "name": name,
        "trackingId": trackingId,
        "latitude": latitude,
        "longitude": longitude,
      });
    } else {
      print('Socket is not connected.');
    }
  }

  void stopTracking() {
    positionStream?.cancel();
    FlutterBackground.disableBackgroundExecution();
  }
}
