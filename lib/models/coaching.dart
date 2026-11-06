import '../util/ids.dart';

/// Client id used for the person holding this phone. Lets a coach preview
/// the client side on one device until cloud sync exists.
const String kMeClientId = 'me';

List<String> _strings(Object? v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

enum CenterStatus { pending, approved, rejected }

/// A gym or fitness center. Only approved centers can run coach accounts.
class TrainingCenter {
  final String id;
  String name;
  String city;
  String contact;
  String about;
  CenterStatus status;
  String? rejectionReason;
  DateTime appliedAt;
  DateTime? approvedAt;

  /// End of the free trial; set on approval.
  DateTime? trialEndsAt;

  TrainingCenter({
    String? id,
    required this.name,
    this.city = '',
    this.contact = '',
    this.about = '',
    this.status = CenterStatus.pending,
    this.rejectionReason,
    DateTime? appliedAt,
    this.approvedAt,
    this.trialEndsAt,
  })  : id = id ?? newId('center'),
        appliedAt = appliedAt ?? DateTime.now();

  factory TrainingCenter.fromJson(Map<String, Object?> j) => TrainingCenter(
        id: j['id'] as String,
        name: j['name'] as String,
        city: (j['city'] as String?) ?? '',
        contact: (j['contact'] as String?) ?? '',
        about: (j['about'] as String?) ?? '',
        status: CenterStatus.values.byName((j['status'] as String?) ?? 'pending'),
        rejectionReason: j['rejectionReason'] as String?,
        appliedAt: _date(j['appliedAt']),
        approvedAt: _date(j['approvedAt']),
        trialEndsAt: _date(j['trialEndsAt']),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'contact': contact,
        'about': about,
        'status': status.name,
        'rejectionReason': rejectionReason,
        'appliedAt': appliedAt.toIso8601String(),
        'approvedAt': approvedAt?.toIso8601String(),
        'trialEndsAt': trialEndsAt?.toIso8601String(),
      };
}

/// A competition result or title shown on a coach's career page.
class Achievement {
  String title; // e.g. "Mr. Addis 2024 — 2nd place"
  String sport; // bodybuilding, boxing, taekwondo…
  int? year;
  Achievement({required this.title, this.sport = '', this.year});

  factory Achievement.fromJson(Map<String, Object?> j) => Achievement(
      title: j['title'] as String, sport: (j['sport'] as String?) ?? '', year: (j['year'] as num?)?.toInt());
  Map<String, Object?> toJson() => {'title': title, 'sport': sport, 'year': year};
}

/// Before/after result of a client, published only with the client's consent.
class Transformation {
  final String id;
  String clientName;
  String summary; // "−12 kg in 16 weeks"
  String details;
  double? weightBefore;
  double? weightAfter;
  int? weeks;
  bool consent;

  Transformation({
    String? id,
    required this.clientName,
    this.summary = '',
    this.details = '',
    this.weightBefore,
    this.weightAfter,
    this.weeks,
    this.consent = false,
  }) : id = id ?? newId('tf');

  factory Transformation.fromJson(Map<String, Object?> j) => Transformation(
        id: j['id'] as String,
        clientName: j['clientName'] as String,
        summary: (j['summary'] as String?) ?? '',
        details: (j['details'] as String?) ?? '',
        weightBefore: (j['weightBefore'] as num?)?.toDouble(),
        weightAfter: (j['weightAfter'] as num?)?.toDouble(),
        weeks: (j['weeks'] as num?)?.toInt(),
        consent: (j['consent'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'clientName': clientName,
        'summary': summary,
        'details': details,
        'weightBefore': weightBefore,
        'weightAfter': weightAfter,
        'weeks': weeks,
        'consent': consent,
      };
}

enum TrainingMode { inGym, online, both }

extension TrainingModeLabel on TrainingMode {
  String get label => switch (this) {
        TrainingMode.inGym => 'In the gym',
        TrainingMode.online => 'Online',
        TrainingMode.both => 'In the gym & online',
      };
}

class CoachProfile {
  final String id;
  String name;
  String centerId;
  String bio;
  List<String> specialties;
  List<String> gyms;
  String city;
  int yearsExperience;
  List<String> certifications;
  String physique; // height, weight, division…
  List<Achievement> achievements;
  List<Transformation> transformations;
  bool acceptingClients;
  int capacity;
  TrainingMode mode;

  /// Sample profiles shown in the directory before real coaches exist.
  bool isSample;

  CoachProfile({
    String? id,
    required this.name,
    required this.centerId,
    this.bio = '',
    List<String>? specialties,
    List<String>? gyms,
    this.city = '',
    this.yearsExperience = 0,
    List<String>? certifications,
    this.physique = '',
    List<Achievement>? achievements,
    List<Transformation>? transformations,
    this.acceptingClients = true,
    this.capacity = 20,
    this.mode = TrainingMode.both,
    this.isSample = false,
  })  : id = id ?? newId('coach'),
        specialties = specialties ?? [],
        gyms = gyms ?? [],
        certifications = certifications ?? [],
        achievements = achievements ?? [],
        transformations = transformations ?? [];

  factory CoachProfile.fromJson(Map<String, Object?> j) => CoachProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        centerId: j['centerId'] as String,
        bio: (j['bio'] as String?) ?? '',
        specialties: _strings(j['specialties']),
        gyms: _strings(j['gyms']),
        city: (j['city'] as String?) ?? '',
        yearsExperience: (j['yearsExperience'] as num?)?.toInt() ?? 0,
        certifications: _strings(j['certifications']),
        physique: (j['physique'] as String?) ?? '',
        achievements: ((j['achievements'] as List?) ?? const [])
            .map((e) => Achievement.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
        transformations: ((j['transformations'] as List?) ?? const [])
            .map((e) => Transformation.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
        acceptingClients: (j['acceptingClients'] as bool?) ?? true,
        capacity: (j['capacity'] as num?)?.toInt() ?? 20,
        mode: TrainingMode.values.byName((j['mode'] as String?) ?? 'both'),
        isSample: (j['isSample'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'centerId': centerId,
        'bio': bio,
        'specialties': specialties,
        'gyms': gyms,
        'city': city,
        'yearsExperience': yearsExperience,
        'certifications': certifications,
        'physique': physique,
        'achievements': achievements.map((a) => a.toJson()).toList(),
        'transformations': transformations.map((t) => t.toJson()).toList(),
        'acceptingClients': acceptingClients,
        'capacity': capacity,
        'mode': mode.name,
        'isSample': isSample,
      };
}

enum LinkStatus { active, ended }

/// A coach's client. [id] is [kMeClientId] for the person on this phone.
class CoachClient {
  final String id;
  final String coachId;
  String name;
  String goal;
  String notes;
  LinkStatus status;
  DateTime since;

  CoachClient({
    String? id,
    required this.coachId,
    required this.name,
    this.goal = '',
    this.notes = '',
    this.status = LinkStatus.active,
    DateTime? since,
  })  : id = id ?? newId('client'),
        since = since ?? DateTime.now();

  bool get isMe => id == kMeClientId;

  factory CoachClient.fromJson(Map<String, Object?> j) => CoachClient(
        id: j['id'] as String,
        coachId: j['coachId'] as String,
        name: j['name'] as String,
        goal: (j['goal'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        status: LinkStatus.values.byName((j['status'] as String?) ?? 'active'),
        since: _date(j['since']),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'coachId': coachId,
        'name': name,
        'goal': goal,
        'notes': notes,
        'status': status.name,
        'since': since.toIso8601String(),
      };
}

enum RequestStatus { pending, accepted, declined }

class CoachingRequest {
  final String id;
  final String coachId;
  String fromName;
  String goal;
  String experience;
  String availability;
  String message;
  RequestStatus status;
  DateTime at;

  CoachingRequest({
    String? id,
    required this.coachId,
    required this.fromName,
    this.goal = '',
    this.experience = '',
    this.availability = '',
    this.message = '',
    this.status = RequestStatus.pending,
    DateTime? at,
  })  : id = id ?? newId('req'),
        at = at ?? DateTime.now();

  factory CoachingRequest.fromJson(Map<String, Object?> j) => CoachingRequest(
        id: j['id'] as String,
        coachId: j['coachId'] as String,
        fromName: j['fromName'] as String,
        goal: (j['goal'] as String?) ?? '',
        experience: (j['experience'] as String?) ?? '',
        availability: (j['availability'] as String?) ?? '',
        message: (j['message'] as String?) ?? '',
        status: RequestStatus.values.byName((j['status'] as String?) ?? 'pending'),
        at: _date(j['at']),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'coachId': coachId,
        'fromName': fromName,
        'goal': goal,
        'experience': experience,
        'availability': availability,
        'message': message,
        'status': status.name,
        'at': at.toIso8601String(),
      };
}

enum GoalType { lift, bodyweight, measurement, habit, custom }

extension GoalTypeLabel on GoalType {
  String get label => switch (this) {
        GoalType.lift => 'Lift target',
        GoalType.bodyweight => 'Body weight',
        GoalType.measurement => 'Measurement',
        GoalType.habit => 'Sessions per week',
        GoalType.custom => 'Custom',
      };
}

/// One card on the shared goal board.
class Goal {
  final String id;
  final String clientId;
  final String coachId;
  GoalType type;
  String title;

  /// Exercise id (lift) or measurement type (measurement).
  String? ref;
  double? start;
  double target;

  /// Manual progress for custom goals; automatic types compute it.
  double? manual;
  DateTime? deadline;
  bool achieved;
  DateTime createdAt;

  Goal({
    String? id,
    required this.clientId,
    required this.coachId,
    required this.type,
    required this.title,
    this.ref,
    this.start,
    required this.target,
    this.manual,
    this.deadline,
    this.achieved = false,
    DateTime? createdAt,
  })  : id = id ?? newId('goal'),
        createdAt = createdAt ?? DateTime.now();

  factory Goal.fromJson(Map<String, Object?> j) => Goal(
        id: j['id'] as String,
        clientId: j['clientId'] as String,
        coachId: j['coachId'] as String,
        type: GoalType.values.byName(j['type'] as String),
        title: j['title'] as String,
        ref: j['ref'] as String?,
        start: (j['start'] as num?)?.toDouble(),
        target: (j['target'] as num).toDouble(),
        manual: (j['manual'] as num?)?.toDouble(),
        deadline: _date(j['deadline']),
        achieved: (j['achieved'] as bool?) ?? false,
        createdAt: _date(j['createdAt']),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'clientId': clientId,
        'coachId': coachId,
        'type': type.name,
        'title': title,
        'ref': ref,
        'start': start,
        'target': target,
        'manual': manual,
        'deadline': deadline?.toIso8601String(),
        'achieved': achieved,
        'createdAt': createdAt.toIso8601String(),
      };
}

class Meal {
  final String id;
  String time; // "07:30"
  String name; // Breakfast
  String items; // free text, one per line
  int? calories;

  Meal({String? id, required this.time, required this.name, this.items = '', this.calories})
      : id = id ?? newId('meal');

  factory Meal.fromJson(Map<String, Object?> j) => Meal(
        id: j['id'] as String,
        time: j['time'] as String,
        name: j['name'] as String,
        items: (j['items'] as String?) ?? '',
        calories: (j['calories'] as num?)?.toInt(),
      );
  Map<String, Object?> toJson() => {'id': id, 'time': time, 'name': name, 'items': items, 'calories': calories};
}

/// Daily nutrition plan a coach sends a client. One plan per client.
class MealPlan {
  final String clientId;
  final String coachId;
  int calories;
  int protein;
  int carbs;
  int fat;
  List<Meal> meals;
  String notes;
  DateTime updatedAt;

  /// Meal ids ticked as eaten, per day key (`2026-11-06`).
  Map<String, List<String>> eaten;

  MealPlan({
    required this.clientId,
    required this.coachId,
    this.calories = 2400,
    this.protein = 160,
    this.carbs = 260,
    this.fat = 70,
    List<Meal>? meals,
    this.notes = '',
    DateTime? updatedAt,
    Map<String, List<String>>? eaten,
  })  : meals = meals ?? [],
        updatedAt = updatedAt ?? DateTime.now(),
        eaten = eaten ?? {};

  factory MealPlan.fromJson(Map<String, Object?> j) => MealPlan(
        clientId: j['clientId'] as String,
        coachId: j['coachId'] as String,
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        protein: (j['protein'] as num?)?.toInt() ?? 0,
        carbs: (j['carbs'] as num?)?.toInt() ?? 0,
        fat: (j['fat'] as num?)?.toInt() ?? 0,
        meals: ((j['meals'] as List?) ?? const [])
            .map((e) => Meal.fromJson(Map<String, Object?>.from(e as Map)))
            .toList(),
        notes: (j['notes'] as String?) ?? '',
        updatedAt: _date(j['updatedAt']),
        eaten: ((j['eaten'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, _strings(v))),
      );

  Map<String, Object?> toJson() => {
        'clientId': clientId,
        'coachId': coachId,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'meals': meals.map((m) => m.toJson()).toList(),
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
        'eaten': eaten,
      };
}

enum ReminderType { training, meal, water, sleep, checkIn, custom }

extension ReminderTypeLabel on ReminderType {
  String get label => switch (this) {
        ReminderType.training => 'Training time',
        ReminderType.meal => 'Meal',
        ReminderType.water => 'Water',
        ReminderType.sleep => 'Sleep',
        ReminderType.checkIn => 'Check-in photo',
        ReminderType.custom => 'Custom',
      };
}

class Reminder {
  final String id;
  final String clientId;
  final String coachId;
  ReminderType type;
  String text;
  String time; // "18:00"

  /// ISO weekdays it repeats on; empty = one-off on [date].
  List<int> weekdays;
  DateTime? date;
  bool active;

  Reminder({
    String? id,
    required this.clientId,
    required this.coachId,
    required this.type,
    required this.text,
    required this.time,
    List<int>? weekdays,
    this.date,
    this.active = true,
  })  : id = id ?? newId('rem'),
        weekdays = weekdays ?? [];

  bool firesOn(DateTime d) {
    if (!active) return false;
    if (weekdays.isEmpty) return date != null && sameDay(date!, d);
    return weekdays.contains(d.weekday);
  }

  factory Reminder.fromJson(Map<String, Object?> j) => Reminder(
        id: j['id'] as String,
        clientId: j['clientId'] as String,
        coachId: j['coachId'] as String,
        type: ReminderType.values.byName(j['type'] as String),
        text: j['text'] as String,
        time: j['time'] as String,
        weekdays: ((j['weekdays'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        date: _date(j['date']),
        active: (j['active'] as bool?) ?? true,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'clientId': clientId,
        'coachId': coachId,
        'type': type.name,
        'text': text,
        'time': time,
        'weekdays': weekdays,
        'date': date?.toIso8601String(),
        'active': active,
      };
}

/// Feedback on a whole workout or one set. Either side can reply.
class CoachComment {
  final String id;
  final String sessionId;
  final String clientId;

  /// `coach` or `client`.
  final String author;
  final String authorName;

  /// Optional: which exercise/set the comment is about.
  final String? exerciseId;
  final int? setIndex;
  final String text;
  final DateTime at;

  CoachComment({
    String? id,
    required this.sessionId,
    required this.clientId,
    required this.author,
    required this.authorName,
    this.exerciseId,
    this.setIndex,
    required this.text,
    DateTime? at,
  })  : id = id ?? newId('cm'),
        at = at ?? DateTime.now();

  factory CoachComment.fromJson(Map<String, Object?> j) => CoachComment(
        id: j['id'] as String,
        sessionId: j['sessionId'] as String,
        clientId: j['clientId'] as String,
        author: j['author'] as String,
        authorName: j['authorName'] as String,
        exerciseId: j['exerciseId'] as String?,
        setIndex: (j['setIndex'] as num?)?.toInt(),
        text: j['text'] as String,
        at: _date(j['at']),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'clientId': clientId,
        'author': author,
        'authorName': authorName,
        'exerciseId': exerciseId,
        'setIndex': setIndex,
        'text': text,
        'at': at.toIso8601String(),
      };
}

enum Audience { client, coach }

class AppNotification {
  final String id;
  final Audience to;
  final String title;
  final String body;

  /// In-app route to open, e.g. `/session/abc`.
  final String? link;
  final DateTime at;
  bool read;

  AppNotification({
    String? id,
    required this.to,
    required this.title,
    required this.body,
    this.link,
    DateTime? at,
    this.read = false,
  })  : id = id ?? newId('n'),
        at = at ?? DateTime.now();

  factory AppNotification.fromJson(Map<String, Object?> j) => AppNotification(
        id: j['id'] as String,
        to: Audience.values.byName(j['to'] as String),
        title: j['title'] as String,
        body: j['body'] as String,
        link: j['link'] as String?,
        at: _date(j['at']),
        read: (j['read'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'to': to.name,
        'title': title,
        'body': body,
        'link': link,
        'at': at.toIso8601String(),
        'read': read,
      };
}
