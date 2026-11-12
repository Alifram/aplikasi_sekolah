import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ScheduleAlarmService {
  ScheduleAlarmService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _exactAlarmPermissionRequested = false;
  static const int _notificationIdBase = 41000;

  static const Map<int, String> _weekdays = {
    DateTime.monday: 'Senin',
    DateTime.tuesday: 'Selasa',
    DateTime.wednesday: 'Rabu',
    DateTime.thursday: 'Kamis',
    DateTime.friday: 'Jumat',
    DateTime.saturday: 'Sabtu',
  };

  static Future<bool> syncForCurrentUser() async {
    await _initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;

    var notificationsEnabled = await android.areNotificationsEnabled() ?? true;
    if (!notificationsEnabled) {
      notificationsEnabled =
          await android.requestNotificationsPermission() ?? false;
    }
    if (!notificationsEnabled) return false;

    var exactAlarmsEnabled =
        await android.canScheduleExactNotifications() ?? false;
    if (!exactAlarmsEnabled && !_exactAlarmPermissionRequested) {
      _exactAlarmPermissionRequested = true;
      exactAlarmsEnabled =
          await android.requestExactAlarmsPermission() ?? false;
      if (!exactAlarmsEnabled) {
        exactAlarmsEnabled =
            await android.canScheduleExactNotifications() ?? false;
      }
    }
    if (!exactAlarmsEnabled) return false;

    final now = DateTime.now();
    final alarms =
        <
          ({
            int id,
            DateTime at,
            String subject,
            String startTime,
            String? room,
          })
        >[];
    for (var offset = 0; offset < 7; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      final weekday = _weekdays[date.weekday];
      if (weekday == null) continue;

      final response = await Supabase.instance.client.rpc(
        'get_my_schedule',
        params: {'p_hari': weekday},
      );
      if (response is! List) {
        throw const FormatException('Respons jadwal alarm tidak valid.');
      }

      if (response.any((item) => item is! Map)) {
        throw const FormatException('Data jadwal alarm tidak valid.');
      }

      for (final item in response.cast<Map>()) {
        final schedule = Map<String, dynamic>.from(item);
        if (schedule['tahun_ajaran']?.toString() != _academicYearFor(date)) {
          continue;
        }
        final startTime =
            schedule['jam_mulai_format']?.toString() ??
            schedule['jam_mulai']?.toString();
        if (startTime == null || startTime.length < 5) {
          throw const FormatException('Jam mulai jadwal tidak valid.');
        }
        final parts = startTime.substring(0, 5).split(':');
        if (parts.length != 2) {
          throw const FormatException('Jam mulai jadwal tidak valid.');
        }
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        final scheduleId = int.tryParse(schedule['id']?.toString() ?? '');
        if (hour == null ||
            hour < 0 ||
            hour > 23 ||
            minute == null ||
            minute < 0 ||
            minute > 59 ||
            scheduleId == null ||
            scheduleId <= 0) {
          throw const FormatException('Data jam atau ID jadwal tidak valid.');
        }

        final triggerAt = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        ).subtract(const Duration(minutes: 5));
        if (!triggerAt.isAfter(now)) continue;

        final id = _notificationIdBase + scheduleId * 7 + date.weekday;
        if (id > 0x7fffffff) {
          throw StateError('ID jadwal terlalu besar untuk alarm perangkat.');
        }
        alarms.add((
          id: id,
          at: triggerAt,
          subject:
              schedule['mata_pelajaran']?.toString() ?? 'pelajaran berikutnya',
          startTime: startTime,
          room: schedule['ruangan']?.toString(),
        ));
      }
    }

    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending.where(
      (notification) => notification.id >= _notificationIdBase,
    )) {
      await _notifications.cancel(id: notification.id);
    }

    for (final alarm in alarms) {
      await _notifications.zonedSchedule(
        id: alarm.id,
        title: 'Pergantian jam pelajaran',
        body: alarm.room == null || alarm.room!.isEmpty
            ? '${alarm.subject} dimulai pukul ${alarm.startTime} (5 menit lagi).'
            : '${alarm.subject} dimulai pukul ${alarm.startTime} di ${alarm.room} '
                  '(5 menit lagi).',
        scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'schedule_change_alarm_v2',
            'Alarm pergantian jam pelajaran',
            channelDescription:
                'Alarm suara lima menit sebelum jadwal pelajaran dimulai.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
    return true;
  }

  static Future<void> _initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  static String _academicYearFor(DateTime date) {
    final yearStarted = date.month >= 7 ? date.year : date.year - 1;
    return '$yearStarted/${yearStarted + 1}';
  }
}
