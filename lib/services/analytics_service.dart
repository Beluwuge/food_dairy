import 'database_helper.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  Future<void> init() async {
    // Optional: initialize Firebase here if required by your lecturer.
    // await Firebase.initializeApp();
  }

  Future<void> event(String name, {String? payload}) async {
    // Local analytics (always works offline)
    await AppDatabase.instance.logEvent(name, payload: payload);

    // Optional: also send to Firebase
    // await FirebaseAnalytics.instance.logEvent(name: name, parameters: payload == null ? null : {'payload': payload});
  }
}
