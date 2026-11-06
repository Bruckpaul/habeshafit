import 'package:flutter/material.dart' show ThemeMode;

enum WeightUnit { kg, lb }

enum TrainingGoal { strength, muscle, fatLoss, general }

extension TrainingGoalLabel on TrainingGoal {
  String get label => switch (this) {
        TrainingGoal.strength => 'Get stronger',
        TrainingGoal.muscle => 'Build muscle',
        TrainingGoal.fatLoss => 'Lose fat',
        TrainingGoal.general => 'Stay fit',
      };
}

class Measurement {
  final String id;
  final DateTime date;

  /// 'bodyweight' (kg) or a body part such as 'waist' (cm).
  final String type;
  final double value;

  const Measurement(
      {required this.id, required this.date, required this.type, required this.value});

  factory Measurement.fromJson(Map<String, Object?> j) => Measurement(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        type: j['type'] as String,
        value: (j['value'] as num).toDouble(),
      );

  Map<String, Object?> toJson() =>
      {'id': id, 'date': date.toIso8601String(), 'type': type, 'value': value};
}

class UserProfile {
  String name;
  TrainingGoal goal;
  String experience; // beginner | intermediate | advanced
  WeightUnit unit;

  /// Planned training days per week; drives the weekly streak.
  int weeklyTarget;
  ThemeMode themeMode;
  String? activeRoutineId;
  int defaultRestSeconds;
  bool onboardingComplete;
  DateTime memberSince;

  /// Per-date override of today's plan: day id, or 'rest' to skip.
  Map<String, String> dayOverrides;

  /// Daily "today's workout" reminder, minutes after midnight; null = off.
  int? dailyReminderMinutes;

  /// Phone alert when the rest timer ends.
  bool restAlerts;

  /// Whether the OS notification permission was already requested.
  bool notificationsAsked;

  UserProfile({
    this.name = '',
    this.goal = TrainingGoal.muscle,
    this.experience = 'beginner',
    this.unit = WeightUnit.kg,
    this.weeklyTarget = 4,
    this.themeMode = ThemeMode.system,
    this.activeRoutineId,
    this.defaultRestSeconds = 90,
    this.onboardingComplete = false,
    DateTime? memberSince,
    Map<String, String>? dayOverrides,
    this.dailyReminderMinutes,
    this.restAlerts = true,
    this.notificationsAsked = false,
  })  : memberSince = memberSince ?? DateTime.now(),
        dayOverrides = dayOverrides ?? {};

  factory UserProfile.fromJson(Map<String, Object?> j) => UserProfile(
        name: (j['name'] as String?) ?? '',
        goal: TrainingGoal.values.byName((j['goal'] as String?) ?? 'muscle'),
        experience: (j['experience'] as String?) ?? 'beginner',
        unit: WeightUnit.values.byName((j['unit'] as String?) ?? 'kg'),
        weeklyTarget: (j['weeklyTarget'] as num?)?.toInt() ?? 4,
        themeMode: ThemeMode.values.byName((j['themeMode'] as String?) ?? 'system'),
        activeRoutineId: j['activeRoutineId'] as String?,
        defaultRestSeconds: (j['defaultRestSeconds'] as num?)?.toInt() ?? 90,
        onboardingComplete: (j['onboardingComplete'] as bool?) ?? false,
        memberSince: j['memberSince'] == null
            ? null
            : DateTime.parse(j['memberSince'] as String),
        dayOverrides: Map<String, String>.from(
            (j['dayOverrides'] as Map?) ?? const <String, String>{}),
        dailyReminderMinutes: (j['dailyReminderMinutes'] as num?)?.toInt(),
        restAlerts: (j['restAlerts'] as bool?) ?? true,
        notificationsAsked: (j['notificationsAsked'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'goal': goal.name,
        'experience': experience,
        'unit': unit.name,
        'weeklyTarget': weeklyTarget,
        'themeMode': themeMode.name,
        'activeRoutineId': activeRoutineId,
        'defaultRestSeconds': defaultRestSeconds,
        'onboardingComplete': onboardingComplete,
        'memberSince': memberSince.toIso8601String(),
        'dayOverrides': dayOverrides,
        'dailyReminderMinutes': dailyReminderMinutes,
        'restAlerts': restAlerts,
        'notificationsAsked': notificationsAsked,
      };
}
