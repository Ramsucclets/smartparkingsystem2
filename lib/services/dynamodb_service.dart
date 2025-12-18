import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model class for parking spot data from DynamoDB
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

/// Service for interacting with DynamoDB via REST API Gateway
class DynamoDBService {
  static const String _baseUrl =
      'https://0d3kse1la3.execute-api.us-east-1.amazonaws.com/dev/parking';

  /// Fetch all parking spots from DynamoDB
  /// Note: Requires a GET endpoint in your Lambda
  Future<List<ParkingSpotData>> fetchParkingSpots() async {
    try {
      print('Fetching from: $_baseUrl');

      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response formats
        List<dynamic> items;
        if (data is List) {
          items = data;
        } else if (data is Map && data.containsKey('items')) {
          items = data['items'];
        } else if (data is Map && data.containsKey('body')) {
          // Handle Lambda proxy response
          final body = data['body'];
          if (body is String) {
            items = jsonDecode(body);
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
      print('ClientException: $e');
      throw Exception(
          'Network error - CORS may be blocking the request. Error: $e');
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching parking data: $e');
    }
  }

  /// Update a parking spot status
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

  /// Fetch a single parking spot by ID (if your API supports it)
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
}
