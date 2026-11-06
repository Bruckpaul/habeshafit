import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/coaching_backend.dart';
import '../logic/stats.dart';
import '../models/coaching.dart';
import '../models/routine.dart';
import '../models/workout.dart';
import '../util/ids.dart';
import 'app_state.dart';

/// Free-trial length for newly approved training centers. Still an open
/// decision in the BRD; change it here.
const int kTrialDays = 30;

enum CoachView { client, coach }

/// Coaching data and actions. Works on top of [AppState] for the phone
/// owner's routines, sessions and measurements.
class CoachingState extends ChangeNotifier {
  final CoachingBackend backend;
  final AppState app;
  CoachingState(this.backend, this.app);

  List<TrainingCenter> centers = [];
  List<CoachProfile> coaches = [];
  List<CoachClient> clients = [];
  List<CoachingRequest> requests = [];
  List<Goal> goals = [];
  List<MealPlan> mealPlans = [];
  List<Reminder> reminders = [];
  List<CoachComment> comments = [];
  List<AppNotification> notifications = [];

  /// The phone owner's coach profile id, if they coach.
  String? myCoachId;
  CoachView view = CoachView.client;

  DateTime get now => app.clock();

  // ---- load / persist ------------------------------------------------------

  Future<void> load() async {
    List<T> read<T>(List<Map<String, Object?>> rows, T Function(Map<String, Object?>) f) => rows.map(f).toList();
    centers = read(await backend.list(Collections.centers), TrainingCenter.fromJson);
    coaches = read(await backend.list(Collections.coaches), CoachProfile.fromJson);
    clients = read(await backend.list(Collections.clients), CoachClient.fromJson);
    requests = read(await backend.list(Collections.requests), CoachingRequest.fromJson)
      ..sort((a, b) => b.at.compareTo(a.at));
    goals = read(await backend.list(Collections.goals), Goal.fromJson);
    mealPlans = read(await backend.list(Collections.mealPlans), MealPlan.fromJson);
    reminders = read(await backend.list(Collections.reminders), Reminder.fromJson);
    comments = read(await backend.list(Collections.comments), CoachComment.fromJson)
      ..sort((a, b) => a.at.compareTo(b.at));
    notifications = read(await backend.list(Collections.notifications), AppNotification.fromJson)
      ..sort((a, b) => b.at.compareTo(a.at));
    final meta = (await backend.list(Collections.meta)).firstOrNull ?? {};
    myCoachId = meta['myCoachId'] as String?;
    view = CoachView.values.byName((meta['view'] as String?) ?? 'client');
    if (meta['seeded'] != true) await _seedSamples();
    notifyListeners();
  }

  Future<void> _saveMeta({bool seeded = true}) => backend.put(Collections.meta, 'meta', {
        'myCoachId': myCoachId,
        'view': view.name,
        'seeded': seeded,
      });

  String _clientKey(CoachClient c) => '${c.coachId}:${c.id}';
  String _mealKey(MealPlan m) => '${m.coachId}:${m.clientId}';

  Future<void> resetAll() async {
    await backend.clear();
    await load();
  }

  /// Two clearly labelled sample coaches so the directory isn't empty.
  Future<void> _seedSamples() async {
    final center = TrainingCenter(
      id: 'sample_center',
      name: 'Sample Fitness Center',
      city: 'Addis Ababa',
      status: CenterStatus.approved,
      about: 'Demo center shown until real centers join.',
      approvedAt: now,
    );
    final a = CoachProfile(
      id: 'sample_coach_strength',
      name: 'Sample Coach · Strength',
      centerId: center.id,
      city: 'Addis Ababa',
      bio: 'Demo profile. Real coaches appear here once training centers are approved.',
      specialties: ['Strength', 'Powerlifting'],
      gyms: ['Sample Fitness Center'],
      yearsExperience: 6,
      certifications: ['Example certification'],
      achievements: [Achievement(title: 'Example: regional powerlifting meet, 1st place', sport: 'Powerlifting', year: 2024)],
      mode: TrainingMode.both,
      isSample: true,
    );
    final b = CoachProfile(
      id: 'sample_coach_combat',
      name: 'Sample Coach · Boxing & Conditioning',
      centerId: center.id,
      city: 'Addis Ababa',
      bio: 'Demo profile for combat-sport conditioning.',
      specialties: ['Boxing', 'Taekwondo', 'Fat loss'],
      gyms: ['Sample Fitness Center'],
      yearsExperience: 4,
      achievements: [Achievement(title: 'Example: national boxing championship', sport: 'Boxing', year: 2023)],
      mode: TrainingMode.inGym,
      isSample: true,
    );
    centers.add(center);
    coaches.addAll([a, b]);
    await backend.put(Collections.centers, center.id, center.toJson());
    await backend.put(Collections.coaches, a.id, a.toJson());
    await backend.put(Collections.coaches, b.id, b.toJson());
    await _saveMeta();
  }

  // ---- lookups -------------------------------------------------------------

  CoachProfile? coachById(String? id) => coaches.where((c) => c.id == id).firstOrNull;
  TrainingCenter? centerById(String? id) => centers.where((c) => c.id == id).firstOrNull;

  CoachProfile? get myCoachProfile => coachById(myCoachId);
  TrainingCenter? get myCenter => centerById(myCoachProfile?.centerId);
  bool get isCoach => myCoachProfile != null;
  bool get coachApproved => myCenter?.status == CenterStatus.approved;
  bool get trialActive => myCenter?.trialEndsAt == null || myCenter!.trialEndsAt!.isAfter(now);
  int get trialDaysLeft => myCenter?.trialEndsAt == null
      ? 0
      : math.max(0, (myCenter!.trialEndsAt!.difference(now).inMinutes / (60 * 24)).ceil());

  /// Coach can make changes: approved and within trial/subscription.
  bool get canCoach => isCoach && coachApproved && trialActive;

  List<CoachClient> get myClients =>
      clients.where((c) => c.coachId == myCoachId && c.status == LinkStatus.active).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  CoachClient? clientOf(String clientId) =>
      clients.where((c) => c.coachId == myCoachId && c.id == clientId).firstOrNull;

  /// The phone owner's active coaching link (as a client).
  CoachClient? get myLink =>
      clients.where((c) => c.id == kMeClientId && c.status == LinkStatus.active).firstOrNull;
  CoachProfile? get myCoach => coachById(myLink?.coachId);

  List<CoachingRequest> get incomingRequests =>
      requests.where((r) => r.coachId == myCoachId && r.status == RequestStatus.pending).toList();
  List<CoachingRequest> get myRequests => requests.where((r) => r.fromName == _meName).toList();

  String get _meName => app.profile.name.isEmpty ? 'Me' : app.profile.name;

  List<Goal> goalsFor(String clientId, String coachId) =>
      goals.where((g) => g.clientId == clientId && g.coachId == coachId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  MealPlan? mealPlanFor(String clientId, String coachId) =>
      mealPlans.where((m) => m.clientId == clientId && m.coachId == coachId).firstOrNull;

  List<Reminder> remindersFor(String clientId, String coachId) =>
      reminders.where((r) => r.clientId == clientId && r.coachId == coachId).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  List<Routine> programsFor(String clientId, String coachId) =>
      app.routines.where((r) => r.clientId == clientId && r.coachId == coachId).toList();

  List<CoachComment> commentsFor(String sessionId) => comments.where((c) => c.sessionId == sessionId).toList();

  /// Reminders for the phone owner today, from their coach.
  List<Reminder> get myRemindersToday {
    final c = myLink;
    if (c == null) return [];
    return remindersFor(kMeClientId, c.coachId).where((r) => r.firesOn(now)).toList();
  }

  int unread(Audience a) => notifications.where((n) => n.to == a && !n.read).length;
  List<AppNotification> inbox(Audience a) => notifications.where((n) => n.to == a).toList();

  /// Sessions the client logged. Only the phone owner's are on this device.
  List<WorkoutSession> sessionsOf(CoachClient c) => c.isMe ? app.sessions : const [];

  /// Share of planned weekly sessions done this week (0..1), or null.
  double? weeklyCompliance(CoachClient c) {
    if (!c.isMe) return null;
    final start = weekStart(now);
    final days = {for (final s in app.sessions.where((s) => !s.start.isBefore(start))) dayKey(s.start)};
    return (days.length / math.max(1, app.profile.weeklyTarget)).clamp(0.0, 1.0);
  }

  // ---- notifications -------------------------------------------------------

  Future<void> _notify(Audience to, String title, String body, {String? link}) async {
    final n = AppNotification(to: to, title: title, body: body, link: link, at: now);
    notifications.insert(0, n);
    await backend.put(Collections.notifications, n.id, n.toJson());
  }

  /// Sends to the client only when the client is the phone owner; other
  /// clients would get a push once cloud sync exists.
  Future<void> _notifyClient(String clientId, String title, String body, {String? link}) async {
    if (clientId == kMeClientId) await _notify(Audience.client, title, body, link: link);
  }

  Future<void> markRead(Audience a) async {
    for (final n in notifications.where((n) => n.to == a && !n.read)) {
      n.read = true;
      await backend.put(Collections.notifications, n.id, n.toJson());
    }
    notifyListeners();
  }

  Future<void> setView(CoachView v) async {
    view = v;
    await _saveMeta();
    notifyListeners();
  }

  // ---- centers & coach account ----------------------------------------------

  /// A training center applies and the phone owner becomes its first coach.
  /// The account stays locked until the admin approves the center.
  Future<void> applyAsCoach({required TrainingCenter center, required CoachProfile profile}) async {
    centers.add(center);
    coaches.add(profile);
    myCoachId = profile.id;
    view = CoachView.coach;
    await backend.put(Collections.centers, center.id, center.toJson());
    await backend.put(Collections.coaches, profile.id, profile.toJson());
    await _saveMeta();
    notifyListeners();
  }

  Future<void> saveCoachProfile(CoachProfile p) async {
    final i = coaches.indexWhere((c) => c.id == p.id);
    if (i == -1) {
      coaches.add(p);
    } else {
      coaches[i] = p;
    }
    await backend.put(Collections.coaches, p.id, p.toJson());
    notifyListeners();
  }

  Future<void> saveCenter(TrainingCenter c) async {
    await backend.put(Collections.centers, c.id, c.toJson());
    notifyListeners();
  }

  /// Admin (app owner) decision on a center application.
  Future<void> reviewCenter(TrainingCenter c, {required bool approve, String? reason}) async {
    c.status = approve ? CenterStatus.approved : CenterStatus.rejected;
    c.rejectionReason = approve ? null : reason;
    if (approve) {
      c.approvedAt = now;
      c.trialEndsAt = now.add(const Duration(days: kTrialDays));
    }
    await backend.put(Collections.centers, c.id, c.toJson());
    if (c.id == myCenter?.id) {
      await _notify(
        Audience.coach,
        approve ? 'Coach account approved' : 'Application not approved',
        approve
            ? '${c.name} is approved. Your $kTrialDays-day free trial has started.'
            : (reason?.isNotEmpty == true ? reason! : 'Contact support for details.'),
      );
    }
    notifyListeners();
  }

  List<TrainingCenter> get pendingCenters => centers.where((c) => c.status == CenterStatus.pending).toList();

  // ---- clients ---------------------------------------------------------------

  Future<CoachClient> addClient({required String name, String goal = '', bool isMe = false}) async {
    final c = CoachClient(id: isMe ? kMeClientId : null, coachId: myCoachId!, name: name, goal: goal, since: now);
    if (isMe) {
      // The owner can have one coach at a time.
      for (final other in clients.where((x) => x.isMe && x.status == LinkStatus.active)) {
        other.status = LinkStatus.ended;
        await backend.put(Collections.clients, _clientKey(other), other.toJson());
      }
    }
    clients.removeWhere((x) => x.coachId == c.coachId && x.id == c.id);
    clients.add(c);
    await backend.put(Collections.clients, _clientKey(c), c.toJson());
    if (isMe) {
      await _notify(Audience.client, 'You have a coach', '${myCoachProfile!.name} added you as a client.', link: '/coach');
    }
    notifyListeners();
    return c;
  }

  Future<void> updateClient(CoachClient c) async {
    await backend.put(Collections.clients, _clientKey(c), c.toJson());
    notifyListeners();
  }

  /// Ends coaching. The client keeps their workout history and programs.
  Future<void> endLink(CoachClient c) async {
    c.status = LinkStatus.ended;
    await backend.put(Collections.clients, _clientKey(c), c.toJson());
    if (c.isMe) {
      await _notify(Audience.client, 'Coaching ended', 'Your workout history stays with you.');
    }
    notifyListeners();
  }

  // ---- requests --------------------------------------------------------------

  Future<void> sendRequest(CoachProfile coach,
      {required String goal, String experience = '', String availability = '', String message = ''}) async {
    final r = CoachingRequest(
      coachId: coach.id,
      fromName: _meName,
      goal: goal,
      experience: experience,
      availability: availability,
      message: message,
      at: now,
    );
    requests.insert(0, r);
    await backend.put(Collections.requests, r.id, r.toJson());
    if (coach.id == myCoachId) {
      await _notify(Audience.coach, 'New coaching request', '${r.fromName}: ${r.goal}', link: '/coach');
    }
    notifyListeners();
  }

  Future<void> answerRequest(CoachingRequest r, {required bool accept}) async {
    r.status = accept ? RequestStatus.accepted : RequestStatus.declined;
    await backend.put(Collections.requests, r.id, r.toJson());
    // On this device every request comes from the phone owner.
    if (accept) {
      await addClient(name: r.fromName, goal: r.goal, isMe: true);
    } else {
      await _notify(Audience.client, 'Request declined', '${myCoachProfile?.name ?? 'The coach'} can\'t take you on right now.');
    }
    notifyListeners();
  }

  // ---- programs --------------------------------------------------------------

  /// Prepares a routine as a coach program for [client] (not yet saved).
  Routine newProgram(CoachClient client) => Routine(
        name: 'Program for ${client.name.split(' ').first}',
        coachId: myCoachId,
        coachName: myCoachProfile?.name,
        clientId: client.id,
      );

  /// Copies one of the coach's own routines into a client program.
  Future<Routine> assignCopy(Routine source, CoachClient client) async {
    final json = source.toJson()
      ..['id'] = newId('routine')
      ..['coachId'] = myCoachId
      ..['coachName'] = myCoachProfile?.name
      ..['clientId'] = client.id
      ..['createdAt'] = now.toIso8601String()
      ..['updatedAt'] = now.toIso8601String();
    final r = Routine.fromJson(json);
    await saveProgram(r);
    return r;
  }

  /// Saves a coach program. For the phone owner it becomes the active plan.
  Future<void> saveProgram(Routine r) async {
    final isNew = app.routineById(r.id) == null;
    await app.saveRoutine(r, makeActive: r.clientId == kMeClientId);
    final coach = myCoachProfile?.name ?? 'Your coach';
    await _notifyClient(
      r.clientId!,
      isNew ? 'New program from your coach' : 'Your coach updated your program',
      '$coach ${isNew ? 'assigned' : 'updated'} "${r.name}". It\'s now your active plan.',
      link: '/routine/${r.id}',
    );
    notifyListeners();
  }

  // ---- goals -----------------------------------------------------------------

  Future<void> saveGoal(Goal g) async {
    final isNew = !goals.any((x) => x.id == g.id);
    goals.removeWhere((x) => x.id == g.id);
    goals.add(g);
    await backend.put(Collections.goals, g.id, g.toJson());
    if (isNew) await _notifyClient(g.clientId, 'New goal on your board', g.title, link: '/coach');
    notifyListeners();
  }

  Future<void> deleteGoal(Goal g) async {
    goals.removeWhere((x) => x.id == g.id);
    await backend.delete(Collections.goals, g.id);
    notifyListeners();
  }

  /// Current value of a goal from logged data (phone owner) or manual entry.
  double? goalCurrent(Goal g) {
    if (g.clientId != kMeClientId || g.type == GoalType.custom) return g.manual;
    switch (g.type) {
      case GoalType.lift:
        if (g.ref == null) return g.manual;
        final b = bestsFor(g.ref!, app.sessions);
        return b.maxWeight == 0 ? g.manual : b.maxWeight;
      case GoalType.bodyweight:
        return app.measurements.where((m) => m.type == 'bodyweight').firstOrNull?.value ?? g.manual;
      case GoalType.measurement:
        return app.measurements.where((m) => m.type == g.ref).firstOrNull?.value ?? g.manual;
      case GoalType.habit:
        final start = weekStart(now);
        return {for (final s in app.sessions.where((s) => !s.start.isBefore(start))) dayKey(s.start)}.length.toDouble();
      case GoalType.custom:
        return g.manual;
    }
  }

  /// 0..1. Handles goals that go down (lose weight, smaller waist).
  double goalProgress(Goal g) {
    if (g.achieved) return 1;
    final cur = goalCurrent(g);
    if (cur == null) return 0;
    final start = g.start ?? (g.type == GoalType.habit ? 0 : null);
    if (start == null || start == g.target) {
      final down = g.start != null && g.target < g.start!;
      return (down ? cur <= g.target : cur >= g.target) ? 1 : 0;
    }
    return ((cur - start) / (g.target - start)).clamp(0.0, 1.0);
  }

  /// Marks goals reached from new data and tells both sides.
  Future<void> refreshGoals() async {
    for (final g in goals.where((g) => !g.achieved && g.clientId == kMeClientId)) {
      if (g.type != GoalType.custom && goalProgress(g) >= 1) {
        g.achieved = true;
        await backend.put(Collections.goals, g.id, g.toJson());
        await _notify(Audience.client, 'Goal reached', g.title, link: '/coach');
        if (g.coachId == myCoachId) {
          await _notify(Audience.coach, '$_meName reached a goal', g.title, link: '/coach/client/$kMeClientId');
        }
      }
    }
    notifyListeners();
  }

  // ---- meal plans ------------------------------------------------------------

  Future<void> saveMealPlan(MealPlan m, {bool fromCoach = true}) async {
    m.updatedAt = now;
    mealPlans.removeWhere((x) => x.clientId == m.clientId && x.coachId == m.coachId);
    mealPlans.add(m);
    await backend.put(Collections.mealPlans, _mealKey(m), m.toJson());
    if (fromCoach) {
      await _notifyClient(m.clientId, 'Meal plan updated', '${m.calories} kcal · ${m.protein} g protein per day', link: '/coach');
    }
    notifyListeners();
  }

  Future<void> toggleMealEaten(MealPlan m, Meal meal) async {
    final k = dayKey(now);
    final list = m.eaten.putIfAbsent(k, () => []);
    list.contains(meal.id) ? list.remove(meal.id) : list.add(meal.id);
    await backend.put(Collections.mealPlans, _mealKey(m), m.toJson());
    notifyListeners();
  }

  /// Share of planned meals ticked over the last 7 days.
  double mealAdherence(MealPlan m) {
    if (m.meals.isEmpty) return 0;
    var ticked = 0;
    for (var i = 0; i < 7; i++) {
      ticked += (m.eaten[dayKey(now.subtract(Duration(days: i)))] ?? const []).length;
    }
    return (ticked / (m.meals.length * 7)).clamp(0.0, 1.0);
  }

  // ---- reminders -------------------------------------------------------------

  Future<void> saveReminder(Reminder r) async {
    final isNew = !reminders.any((x) => x.id == r.id);
    reminders.removeWhere((x) => x.id == r.id);
    reminders.add(r);
    await backend.put(Collections.reminders, r.id, r.toJson());
    if (isNew) {
      await _notifyClient(r.clientId, 'New reminder from your coach', '${r.type.label} at ${r.time}: ${r.text}', link: '/coach');
    }
    notifyListeners();
  }

  Future<void> deleteReminder(Reminder r) async {
    reminders.removeWhere((x) => x.id == r.id);
    await backend.delete(Collections.reminders, r.id);
    notifyListeners();
  }

  // ---- comments --------------------------------------------------------------

  Future<void> addComment({
    required WorkoutSession session,
    required String clientId,
    required bool fromCoach,
    required String text,
    String? exerciseId,
    int? setIndex,
  }) async {
    final c = CoachComment(
      sessionId: session.id,
      clientId: clientId,
      author: fromCoach ? 'coach' : 'client',
      authorName: fromCoach ? (myCoachProfile?.name ?? 'Coach') : _meName,
      exerciseId: exerciseId,
      setIndex: setIndex,
      text: text,
      at: now,
    );
    comments.add(c);
    await backend.put(Collections.comments, c.id, c.toJson());
    if (fromCoach) {
      await _notifyClient(clientId, 'Coach feedback on ${session.name}', text, link: '/session/${session.id}');
    } else if (myLink?.coachId == myCoachId && myCoachId != null) {
      await _notify(Audience.coach, '$_meName replied on ${session.name}', text, link: '/session/${session.id}');
    }
    notifyListeners();
  }

  // ---- hooks from the tracker ------------------------------------------------

  /// Tells the coach about a finished workout and updates goals.
  Future<void> onWorkoutFinished(WorkoutSession s) async {
    final link = myLink;
    if (link != null && link.coachId == myCoachId) {
      final prs = s.records.isEmpty ? '' : ' · ${s.records.length} PR${s.records.length == 1 ? '' : 's'}';
      await _notify(Audience.coach, '$_meName finished ${s.name}', '${s.doneSets} sets$prs', link: '/session/${s.id}');
    }
    await refreshGoals();
  }
}
