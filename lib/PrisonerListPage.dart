import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'Live.dart';

String apiUrl = dotenv.env['API_URL'] ?? '';

class PrisonerListPage extends StatefulWidget {
  @override
  _PrisonerListPageState createState() => _PrisonerListPageState();
}

class _PrisonerListPageState extends State<PrisonerListPage> {
  List<Map<String, dynamic>> prisoners = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(context);
    _fetchPrisoners(context);
  }

  Future<void> _checkLoginStatus(BuildContext context) async {
    bool isLogged = await _isLogged();
    if (isLogged) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LocationTrackingScreen()),
      );
    }
  }

  Future<bool> _isLogged() async {
    final prefs = await SharedPreferences.getInstance();
    int? prisonerId = prefs.getInt('prisonerId');
    String? trackingId = prefs.getString('trackingId');

    return prisonerId != null && trackingId != null;
  }

  // Fetch prisoners from API
  Future<void> _fetchPrisoners(BuildContext context) async {
    final response = await http.get(Uri.parse(
        '$apiUrl/api/v1/prisoner/mobile/all?page=1&limit=20'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        prisoners = List<Map<String, dynamic>>.from(data['prisoners']);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });

      // Show error message in an AlertDialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Failed to fetch prisoners. Please try again later.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // Select prisoner and assign a tracking ID
  Future<void> _selectPrisoner(
      BuildContext context, Map<String, dynamic> prisoner) async {
    final prefs = await SharedPreferences.getInstance();
    int? prisonerId = prefs.getInt('prisonerId');
    String? trackingId = prefs.getString('trackingId');
    print("trackingId: $trackingId, prisonerId: $prisonerId");

    // final String trackingId = Uuid().v4(); // Generate a new UUID
    if (trackingId == null || prisonerId == null) {
      trackingId = Uuid().v4();
      // Add tracking device
      await _addTrackingDevice(trackingId);

      // Update prisoner details with the tracking ID
      await _updatePrisonerTrackingId(prisoner['prisoner_id'], trackingId);

      // Save the tracking ID in SharedPreferences to avoid reloading data
      await prefs.setString('trackingId', trackingId);
      await prefs.setInt('prisonerId', prisoner['prisoner_id']);
      print(prisoner);
      final String name = prisoner['first_name'] + ' ' + prisoner['last_name'];
      print(name);
      await prefs.setString('name', name);

      // Show a success message (you can customize this)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Tracking ID set for ${prisoner['first_name']} ${prisoner['last_name']}')));
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LocationTrackingScreen()),
    );

    // Navigate to a new page to show prisoner details or stay on the same page
    // Here, you can navigate to a new page or update UI as needed
  }

  //Add tracking devices using API
  Future<void> _addTrackingDevice(String trackingId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/api/v1/device/add'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'device_id': trackingId, 'assigned_to': 'Prisoner'}),
    );

    if (response.statusCode == 201) {
      print('Device added successfully');
    } else {
      // Handle API update failure
      print('Failed to add device');
    }
  }

  // Update prisoner details using API
  Future<void> _updatePrisonerTrackingId(
      int prisonerId, String trackingId) async {
    final response = await http.put(
      Uri.parse(
          '$apiUrl/api/v1/prisoner/update/$prisonerId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'tracking_device_id': trackingId,
      }),
    );

    if (response.statusCode == 200) {
      print('Prisoner updated successfully');
    } else {
      // Handle API update failure
      print('Failed to update prisoner');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Prisoner List')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: prisoners.length,
              itemBuilder: (context, index) {
                final prisoner = prisoners[index];
                // print(prisoner);
                return ListTile(
                  title: Text(
                      '${prisoner['first_name']} ${prisoner['last_name']}'),
                  subtitle: Text('Status: ${prisoner['status']}'),
                  onTap: () => _selectPrisoner(context, prisoner),
                );
              },
            ),
    );
  }
}
