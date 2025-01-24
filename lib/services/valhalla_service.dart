import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:async';

class ValhallaService {
  final String baseUrl;
  final Duration timeout;

  ValhallaService({
    this.baseUrl = 'https://valhalla1.openstreetmap.de',
    this.timeout = const Duration(seconds: 10),
  });

  // 调用 Valhalla API 获取路线数据
  Future<Map<String, dynamic>> getRouteData(LatLng start, LatLng end,
      {String costing = 'pedestrian'}) async {
    final url = '$baseUrl/route';

    final body = jsonEncode({
      "locations": [
        {"lat": start.latitude, "lon": start.longitude},
        {"lat": end.latitude, "lon": end.longitude}
      ],
      "costing": costing,
      "directions_options": {"units": "kilometers"}
    });

    try {
      await Future.delayed(const Duration(seconds: 1)); // 避免速率限制
      final response = await http
          .post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['trip'] != null &&
            data['trip']['legs'] != null &&
            data['trip']['legs'].isNotEmpty) {
          print('Valhalla trip data: ${data['trip']}');

          final leg = data['trip']['legs'][0];
          final shape = leg['shape'] as String?;
          if (shape != null && shape.isNotEmpty) {
            return {
              'trip': data['trip'], // 返回完整的 trip 数据
              'polyline': shape,
            };
          } else {
            throw Exception('Invalid response format: Missing shape data');
          }
        } else {
          throw Exception('Invalid response format: Missing trip/legs data');
        }
      } else {
        throw Exception(
            'Failed to fetch route: ${response.statusCode} ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error occurred: $e');
    } on TimeoutException catch (e) {
      throw Exception('Request to Valhalla API timed out: $e');
    } catch (e) {
      throw Exception('Unexpected error occurred: $e');
    }
  }

  // 解码 polyline 为 LatLng 列表
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E6, lng / 1E6)); // 修改为 1E6
    }
    return points;
  }

  // 获取逐步导航指令
  List<Map<String, dynamic>> getTurnByTurnInstructions(
      Map<String, dynamic> tripData) {
    print('getTurnByTurnInstructions called with tripData: $tripData'); // 调试输出

    List<Map<String, dynamic>> parsedInstructions = [];

    // 修改为访问 tripData['trip']['legs']
    if (tripData.containsKey('trip') && tripData['trip'].containsKey('legs')) {
      var legs = tripData['trip']['legs'];

      if (legs is List && legs.isNotEmpty) {
        print('Trip legs found: ${legs.length} legs');

        var maneuvers = legs[0]['maneuvers'];

        if (maneuvers != null && maneuvers is List && maneuvers.isNotEmpty) {
          print('Maneuvers found: ${maneuvers.length} maneuvers');

          for (var maneuver in maneuvers) {
            print('Parsing maneuver: ${maneuver['instruction']}');
            parsedInstructions.add({
              'instruction': maneuver['instruction'],
              'distance': maneuver['length'], // 距离信息
              'type': maneuver['type'], // 转向类型
              'street_name':
                  maneuver['street_names']?.join(', ') ?? '未知道路',
            });
          }
        } else {
          print('No maneuvers found in the first leg.');
        }
      } else {
        print('No legs found in tripData["trip"].');
      }
    } else {
      print('No "trip" or "legs" key found in tripData.');
    }

    print('Parsed instructions: ${parsedInstructions.length} steps');
    return parsedInstructions;
  }
}
