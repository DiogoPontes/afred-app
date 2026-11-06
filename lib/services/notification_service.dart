// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);

    // Solicita permissão no Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Cancela todas as notificações de estudo e reagenda com base nos schedules ativos
  static Future<void> rescheduleStudyNotifications() async {
    await init();

    // Cancela todas as notificações de estudo (IDs no range 10000–19999)
    for (int i = 10000; i < 20000; i++) {
      await _plugin.cancel(i);
    }

    final schedulesBox = Hive.box('alfred_study_schedules');
    final studyTypesBox = Hive.box('alfred_study_types');

    int notifId = 10000;

    for (var key in schedulesBox.keys) {
      final raw = schedulesBox.get(key);
      if (raw == null) continue;
      final sched = Map<String, dynamic>.from(raw as Map);

      final isActive = sched['isActive'] as bool? ?? true;
      if (!isActive) continue;

      final weekdays = (sched['weekdays'] as List?)?.cast<int>() ?? [];
      final hour = sched['timeHour'] as int? ?? 0;
      final minute = sched['timeMinute'] as int? ?? 0;
      final minutesBefore = sched['notifyMinutesBefore'] as int? ?? 15;

      final typeKey = sched['studyTypeKey'];
      final typeRaw = studyTypesBox.get(typeKey);
      final typeName = typeRaw != null
          ? ((typeRaw as Map).cast<String, dynamic>()['name'] as String? ?? 'Estudo')
          : 'Estudo';

      // Notifica X minutos antes
      final notifyHour = (hour * 60 + minute - minutesBefore) ~/ 60;
      final notifyMinute = (hour * 60 + minute - minutesBefore) % 60;
      if (notifyHour < 0) continue; // horário inválido

      for (final weekday in weekdays) {
        // weekday: 1=seg ... 7=dom (padrão Dart)
        final nextDate = _nextWeekday(weekday, notifyHour, notifyMinute);
        if (nextDate == null) continue;

        await _plugin.zonedSchedule(
          notifId++,
          '📚 Sessão de estudo em breve',
          '$typeName começa em $minutesBefore minutos',
          tz.TZDateTime.from(nextDate, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'study_reminders',
              'Lembretes de Estudo',
              channelDescription: 'Notificações de sessões de estudo agendadas',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  static DateTime? _nextWeekday(int weekday, int hour, int minute) {
    final now = DateTime.now();
    int daysUntil = (weekday - now.weekday) % 7;
    if (daysUntil == 0) {
      final todayTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (todayTime.isBefore(now)) daysUntil = 7;
    }
    final target = now.add(Duration(days: daysUntil));
    return DateTime(target.year, target.month, target.day, hour, minute);
  }
}