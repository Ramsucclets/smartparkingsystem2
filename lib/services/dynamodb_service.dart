import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class ParkingSpotData {
  final String spotId;
  final String status;
  final String lastUpdated;
  final bool isOccupied;

  ParkingSpotData({
    required this.spotId,
    required this.status,
    required this.lastUpdated,
    required this.isOccupied,
  });

  factory ParkingSpotData.fromJson(Map<String, dynamic> json) {
    return ParkingSpotData(
      spotId: json['spotId'] ?? '',
      status: json['status'] ?? '',
      lastUpdated: json['lastUpdated'] ?? '',
      isOccupied: json['isOccupied'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spotId': spotId,
      'status': status,
      'lastUpdated': lastUpdated,
      'isOccupied': isOccupied,
    };
  }
}

class DynamoDBService {
  static const String _baseUrl =
      'https://0d3kse1la3.execute-api.us-east-1.amazonaws.com/dev/parking';

  Future<List<ParkingSpotData>> fetchParkingSpots() async {
    try {
      developer.log('Fetching from: $_baseUrl');

      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Accept': 'application/json',
        },
      );

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<dynamic> items;
        if (data is List) {
          items = data;
        } else if (data is Map && data.containsKey('spots')) {
          items = data['spots'];
        } else if (data is Map && data.containsKey('items')) {
          items = data['items'];
        } else if (data is Map && data.containsKey('body')) {
          final body = data['body'];
          if (body is String) {
            final parsedBody = jsonDecode(body);
            if (parsedBody is Map && parsedBody.containsKey('spots')) {
              items = parsedBody['spots'];
            } else if (parsedBody is List) {
              items = parsedBody;
            } else {
              items = [parsedBody];
            }
          } else if (body is Map && body.containsKey('spots')) {
            items = body['spots'];
          } else {
            items = body is List ? body : [body];
          }
        } else {
          items = [data];
        }

        return items.map((item) => ParkingSpotData.fromJson(item)).toList();
      } else {
        throw Exception(
            'Failed to fetch parking spots: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      developer.log('ClientException: $e');
      throw Exception(
          'Network error - CORS may be blocking the request. Error: $e');
    } catch (e) {
      developer.log('Error: $e');
      throw Exception('Error fetching parking data: $e');
    }
  }

  Future<bool> updateParkingSpot({
    required String spotId,
    required String status,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'spotId': spotId,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update spot');
      }
    } catch (e) {
      throw Exception('Error updating parking spot: $e');
    }
  }

  Future<ParkingSpotData?> fetchParkingSpotById(String spotId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?spotId=$spotId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ParkingSpotData.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, bool>> initializeSpots(List<String> spotIds) async {
    final Map<String, bool> availability = {};

    try {
      final existingSpots = await fetchParkingSpots();
      final existingIds = existingSpots.map((s) => s.spotId).toSet();

      for (final spot in existingSpots) {
        availability[spot.spotId] = !spot.isOccupied;
      }

      final missingSpotIds =
          spotIds.where((id) => !existingIds.contains(id)).toList();

      for (final spotId in missingSpotIds) {
        try {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'spotId': spotId,
              'status': 'Available',
            }),
          );

          if (response.statusCode == 200) {
            availability[spotId] = true;
            developer.log('Initialized spot $spotId in DynamoDB');
          }
        } catch (e) {
          developer.log('Failed to initialize spot $spotId: $e');
          availability[spotId] = true;
        }
      }

      return availability;
    } catch (e) {
      developer.log('Error initializing spots: $e');
      for (final spotId in spotIds) {
        availability[spotId] = true;
      }
      return availability;
    }
  }
}
