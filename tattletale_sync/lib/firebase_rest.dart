import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _apiKey = 'AIzaSyDn_iWwCgTIXq1gDzhC3BHR8I5scfF-MFA';
const _projectId = 'tatletale-16660';

class FirebaseRest {
  static Future<bool> signIn(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'email': email, 'password': password, 'returnSecureToken': true}),
      );
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', data['refreshToken'] ?? '');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getIdToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) return null;

      final res = await http.post(
        Uri.parse(
            'https://securetoken.googleapis.com/v1/token?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'grant_type': 'refresh_token', 'refresh_token': refreshToken}),
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final newToken = data['refresh_token'] as String?;
      if (newToken != null) {
        await prefs.setString('refresh_token', newToken);
      }
      return data['id_token'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> pushUsage(
      String familyId, List<Map<String, dynamic>> usage) async {
    try {
      final idToken = await getIdToken();
      if (idToken == null) return false;

      final now = DateTime.now().toUtc().toIso8601String();
      final values = usage
          .map((u) => {
                'mapValue': {
                  'fields': {
                    'packageName': {'stringValue': u['packageName'] ?? ''},
                    'appName': {'stringValue': u['appName'] ?? ''},
                    'usageMinutes': {
                      'integerValue': '${u['usageMinutes'] ?? 0}'
                    },
                  }
                }
              })
          .toList();

      final body = {
        'fields': {
          'liveUsage': {
            'arrayValue': {'values': values}
          },
          'liveUsageUpdated': {'timestampValue': now},
        }
      };

      final url =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/families/$familyId'
          '?updateMask.fieldPaths=liveUsage&updateMask.fieldPaths=liveUsageUpdated';

      final res = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Checks the refreshRequestedAt field on the family doc
  static Future<DateTime?> getRefreshRequestTime(String familyId) async {
    try {
      final idToken = await getIdToken();
      if (idToken == null) return null;

      final url =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/families/$familyId';
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final tsStr =
          data['fields']?['refreshRequestedAt']?['timestampValue'] as String?;
      if (tsStr == null) return null;
      return DateTime.tryParse(tsStr)?.toUtc();
    } catch (_) {
      return null;
    }
  }
}
