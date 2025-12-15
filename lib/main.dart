import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNotifications();

  final state = ContactLensState();
  await state.load();

  runApp(
    ChangeNotifierProvider<ContactLensState>.value(
      value: state,
      child: const MyApp(),
    ),
  );
}

Future<void> _initializeNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await _notificationsPlugin.initialize(initializationSettings);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactLensState>(
      builder: (context, state, _) {
        return MaterialApp(
          title: 'コンタクト交換管理',
          locale: const Locale('ja', 'JP'),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: state.themeColor,
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              iconTheme: IconThemeData(color: Colors.white),
              actionsIconTheme: IconThemeData(color: Colors.white),
            ),
            useMaterial3: true,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ja', 'JP'),
            Locale('en', 'US'),
          ],
          home: const HomeScreen(),
        );
      },
    );
  }
}

enum NotificationTimeType { dayBefore, dayOf, inventoryAlert }

class ContactProfile {
  ContactProfile({
    required this.name,
    required this.lensType,
    required this.cycleLength,
    required this.startDate,
    required this.autoSchedule,
    required this.notifyDayBefore,
    required this.notifyDayBeforeTime,
    required this.notifyDayOf,
    required this.notifyDayOfTime,
    required this.themeColorIndex,
    required this.inventoryAlertEnabled,
    required this.inventoryAlertTime,
    required this.showInventory,
    required this.inventoryCount,
    required this.inventoryThreshold,
    required this.soundEnabled,
    required this.isRegistered,
  });

  factory ContactProfile.primaryDefaults() => ContactProfile(
        name: 'コンタクト1',
        lensType: 'コンタクト',
        cycleLength: 14,
        startDate: DateTime.now(),
        autoSchedule: true,
        notifyDayBefore: true,
        notifyDayBeforeTime: const TimeOfDay(hour: 20, minute: 0),
        notifyDayOf: true,
        notifyDayOfTime: const TimeOfDay(hour: 7, minute: 0),
        themeColorIndex: 0,
        inventoryAlertEnabled: true,
        inventoryAlertTime: const TimeOfDay(hour: 8, minute: 30),
        showInventory: false,
        inventoryCount: null,
        inventoryThreshold: 2,
        soundEnabled: true,
        isRegistered: true,
      );

  factory ContactProfile.secondaryPlaceholder() => ContactProfile(
        name: 'コンタクト2',
        lensType: 'コンタクト',
        cycleLength: 14,
        startDate: DateTime.now(),
        autoSchedule: true,
        notifyDayBefore: true,
        notifyDayBeforeTime: const TimeOfDay(hour: 20, minute: 0),
        notifyDayOf: true,
        notifyDayOfTime: const TimeOfDay(hour: 7, minute: 0),
        themeColorIndex: 0,
        inventoryAlertEnabled: true,
        inventoryAlertTime: const TimeOfDay(hour: 8, minute: 30),
        showInventory: false,
        inventoryCount: null,
        inventoryThreshold: 2,
        soundEnabled: true,
        isRegistered: false,
      );

  final String name;
  final String lensType;
  final int cycleLength;
  final DateTime startDate;
  final bool autoSchedule;
  final bool notifyDayBefore;
  final TimeOfDay notifyDayBeforeTime;
  final bool notifyDayOf;
  final TimeOfDay notifyDayOfTime;
  final int themeColorIndex;
  final bool inventoryAlertEnabled;
  final TimeOfDay inventoryAlertTime;
  final bool showInventory;
  final int? inventoryCount;
  final int inventoryThreshold;
  final bool soundEnabled;
  final bool isRegistered;

  ContactProfile copyWith({
    String? name,
    String? lensType,
    int? cycleLength,
    DateTime? startDate,
    bool? autoSchedule,
    bool? notifyDayBefore,
    TimeOfDay? notifyDayBeforeTime,
    bool? notifyDayOf,
    TimeOfDay? notifyDayOfTime,
    int? themeColorIndex,
    bool? inventoryAlertEnabled,
    TimeOfDay? inventoryAlertTime,
    bool? showInventory,
    int? inventoryCount,
    int? inventoryThreshold,
    bool? soundEnabled,
    bool? isRegistered,
  }) {
    return ContactProfile(
      name: name ?? this.name,
      lensType: lensType ?? this.lensType,
      cycleLength: cycleLength ?? this.cycleLength,
      startDate: startDate ?? this.startDate,
      autoSchedule: autoSchedule ?? this.autoSchedule,
      notifyDayBefore: notifyDayBefore ?? this.notifyDayBefore,
      notifyDayBeforeTime: notifyDayBeforeTime ?? this.notifyDayBeforeTime,
      notifyDayOf: notifyDayOf ?? this.notifyDayOf,
      notifyDayOfTime: notifyDayOfTime ?? this.notifyDayOfTime,
      themeColorIndex: themeColorIndex ?? this.themeColorIndex,
      inventoryAlertEnabled: inventoryAlertEnabled ?? this.inventoryAlertEnabled,
      inventoryAlertTime: inventoryAlertTime ?? this.inventoryAlertTime,
      showInventory: showInventory ?? this.showInventory,
      inventoryCount: inventoryCount ?? this.inventoryCount,
      inventoryThreshold: inventoryThreshold ?? this.inventoryThreshold,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lensType': lensType,
      'cycleLength': cycleLength,
      'startDate': startDate.millisecondsSinceEpoch,
      'autoSchedule': autoSchedule,
      'notifyDayBefore': notifyDayBefore,
      'notifyDayBeforeTime': notifyDayBeforeTime.hour * 60 + notifyDayBeforeTime.minute,
      'notifyDayOf': notifyDayOf,
      'notifyDayOfTime': notifyDayOfTime.hour * 60 + notifyDayOfTime.minute,
      'themeColorIndex': themeColorIndex,
      'inventoryAlertEnabled': inventoryAlertEnabled,
      'inventoryAlertTime':
          inventoryAlertTime.hour * 60 + inventoryAlertTime.minute,
      'showInventory': showInventory,
      'inventoryCount': inventoryCount,
      'inventoryThreshold': inventoryThreshold,
      'soundEnabled': soundEnabled,
      'isRegistered': isRegistered,
    };
  }

  factory ContactProfile.fromMap(Map<String, dynamic> map) {
    final notifyBeforeMinutes = map['notifyDayBeforeTime'] as int?;
    final notifyOfMinutes = map['notifyDayOfTime'] as int?;
    final inventoryAlertMinutes = map['inventoryAlertTime'] as int?;

    return ContactProfile(
      name: map['name'] as String? ?? 'コンタクト1',
      lensType: map['lensType'] as String? ?? 'コンタクト',
      cycleLength: map['cycleLength'] as int? ?? 14,
      startDate: DateTime.fromMillisecondsSinceEpoch(
        map['startDate'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      autoSchedule: map['autoSchedule'] as bool? ?? true,
      notifyDayBefore: map['notifyDayBefore'] as bool? ?? true,
      notifyDayBeforeTime: _timeFromMinutes(
        notifyBeforeMinutes,
        const TimeOfDay(hour: 20, minute: 0),
      ),
      notifyDayOf: map['notifyDayOf'] as bool? ?? true,
      notifyDayOfTime: _timeFromMinutes(
        notifyOfMinutes,
        const TimeOfDay(hour: 7, minute: 0),
      ),
      themeColorIndex: map['themeColorIndex'] as int? ?? 0,
      inventoryAlertEnabled: map['inventoryAlertEnabled'] as bool? ?? true,
      inventoryAlertTime: _timeFromMinutes(
        inventoryAlertMinutes,
        const TimeOfDay(hour: 8, minute: 30),
      ),
      showInventory: map['showInventory'] as bool? ?? false,
      inventoryCount: map['inventoryCount'] as int?,
      inventoryThreshold: map['inventoryThreshold'] as int? ?? 2,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      isRegistered: map['isRegistered'] as bool? ?? true,
    );
  }

  ContactProfile autoAdvanced(DateTime today) {
    if (!autoSchedule) {
      return this;
    }

    var start = _dateOnly(startDate);
    var nextExchange = start.add(Duration(days: cycleLength));

    while (!today.isBefore(nextExchange)) {
      start = nextExchange;
      nextExchange = start.add(Duration(days: cycleLength));
    }

    if (start != _dateOnly(startDate)) {
      return copyWith(startDate: start);
    }
    return this;
  }

  static TimeOfDay _timeFromMinutes(int? minutes, TimeOfDay fallback) {
    if (minutes == null) {
      return fallback;
    }
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}

class ContactLensState extends ChangeNotifier {
  ContactLensState();

  static const _profileKeyPrefix = 'contactProfile_';
  static const _selectedProfileIndexKey = 'selectedProfileIndex';

  static const _cycleKey = 'cycleLength';
  static const _startDateKey = 'startDate';
  static const _autoScheduleKey = 'autoSchedule';
  static const _notifyDayBeforeKey = 'notifyDayBefore';
  static const _notifyDayBeforeTimeKey = 'notifyDayBeforeTime';
  static const _notifyDayOfKey = 'notifyDayOf';
  static const _notifyDayOfTimeKey = 'notifyDayOfTime';
  static const _themeColorIndexKey = 'themeColorIndex';
  static const _inventoryAlertEnabledKey = 'inventoryAlertEnabled';
  static const _showInventoryKey = 'showInventory';
  static const _inventoryCountKey = 'inventoryCount';
  static const _inventoryThresholdKey = 'inventoryThreshold';
  static const _inventoryOnboardingDismissedKey =
      'inventoryOnboardingDismissed';
  static const _soundEnabledKey = 'soundEnabled';
  static const _showSecondProfileKey = 'showSecondProfile';

  static const _lensTypeKey = 'lensType';
  static const int oneDayCycle = 1;
  static const int twoWeekCycle = 14;
  static const int oneMonthCycle = 30;

  static const int _dayBeforeNotificationId = 1001;
  static const int _dayOfNotificationId = 1002;
  static const int _inventoryAlertNotificationId = 1003;
  static const TimeOfDay _defaultInventoryAlertTime =
      TimeOfDay(hour: 8, minute: 30);
  static const int _secondProfileDefaultColorIndex = 1;

  static const List<Color> _availableThemeColors = <Color>[
    Color(0xFF5385C8),
    Color(0xE64DBE7D),
    Color(0xE6CC874B),
    Color(0xE6825BA7),
    Color(0xFF934545),
  ];

  SharedPreferences? _prefs;

  final List<ContactProfile> _profiles = [
    ContactProfile.primaryDefaults(),
    ContactProfile.secondaryPlaceholder(),
  ];
  int _selectedProfileIndex = 0;
  bool _inventoryOnboardingDismissed = false;
  bool _showSecondProfile = true;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _selectedProfileIndex = _prefs?.getInt(_selectedProfileIndexKey) ?? 0;
    _inventoryOnboardingDismissed =
        _prefs?.getBool(_inventoryOnboardingDismissedKey) ?? false;
    _showSecondProfile = _prefs?.getBool(_showSecondProfileKey) ?? true;

    final storedPrimary = await _loadProfile(0);
    final storedSecondary = await _loadProfile(1);

    _profiles[0] = storedPrimary ?? await _loadLegacyProfile();
    _profiles[1] = storedSecondary ?? ContactProfile.secondaryPlaceholder();

    if (!_profiles[1].isRegistered) {
      _selectedProfileIndex = 0;
    } else if (!_showSecondProfile) {
      _selectedProfileIndex = 0;
    }
    _selectedProfileIndex =
        _selectedProfileIndex.clamp(0, _profiles.length - 1).toInt();

    _autoAdvanceAll();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  ContactProfile get _profile => _profiles[_selectedProfileIndex];
  int get selectedProfileIndex => _selectedProfileIndex;
  bool get hasSecondProfile => _profiles[1].isRegistered;
  bool get showSecondProfile => _showSecondProfile;
  String get currentProfileName => _profile.name;
  String get currentLensType => _profile.lensType;
  String profileName(int index) => _profiles[index].name;
  String profileLensType(int index) => _profiles[index].lensType;

  int get cycleLength => _profile.cycleLength;
  DateTime get startDate => _profile.startDate;
  DateTime get exchangeDate => _profile.startDate.add(Duration(days: _profile.cycleLength));
  bool get autoSchedule => _profile.autoSchedule;
  bool get notifyDayBefore => _profile.notifyDayBefore;
  TimeOfDay get notifyDayBeforeTime => _profile.notifyDayBeforeTime;
  bool get notifyDayOf => _profile.notifyDayOf;
  TimeOfDay get notifyDayOfTime => _profile.notifyDayOfTime;
  Color get themeColor => _colorWithDefaultOpacity(_profile.themeColorIndex);
  int get themeColorIndex => _profile.themeColorIndex;
  bool get notifyInventoryAlert => _profile.inventoryAlertEnabled;
  TimeOfDay get inventoryAlertTime => _profile.inventoryAlertTime;
  bool get showInventory => _profile.showInventory;
  int? get inventoryCount => _profile.inventoryCount;
  int get inventoryThreshold => _profile.inventoryThreshold;
  bool get inventoryOnboardingDismissed => _inventoryOnboardingDismissed;
  bool get isInventoryConfigured => _profile.inventoryCount != null;
  bool get soundEnabled => _profile.soundEnabled;
  String get cycleLabel {
    if (_profile.cycleLength == oneDayCycle) {
      return '1day';
    }
    if (_profile.cycleLength == oneMonthCycle) {
      return '1month';
    }
    return '${_profile.cycleLength == twoWeekCycle ? '2week' : _profile.cycleLength}';
  }

  List<Color> get availableThemeColors => List.unmodifiable(_availableThemeColors);
  Color colorForIndex(int index) => _colorWithDefaultOpacity(index);

  int get remainingDays {
    final today = _today();
    final exchange = _dateOnly(exchangeDate);
    final diff = exchange.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }

  int get overdueDays {
    final today = _today();
    final exchange = _dateOnly(exchangeDate);
    final diff = today.difference(exchange).inDays;
    return diff > 0 ? diff : 0;
  }

  double get progress {
    final total = _profile.cycleLength;
    if (total == 0) {
      return 0;
    }
    final today = _today();
    final elapsed = today.difference(_dateOnly(_profile.startDate)).inDays;
    final clamped = elapsed.clamp(0, total).toDouble();
    return clamped / total;
  }

  bool get shouldShowInventoryAlert => _profile.showInventory &&
      _profile.inventoryCount != null &&
      _profile.inventoryCount! <= _profile.inventoryThreshold;

  bool get shouldShowInventoryOnboarding =>
      !_inventoryOnboardingDismissed && _profile.inventoryCount == null;

  Future<void> recordExchangeToday() async {
    await _updateProfile(
      (current) => current.copyWith(startDate: DateTime.now()),
    );
  }

  Future<void> recordExchangeOn(DateTime start) async {
    await _updateProfile(
      (current) => current.copyWith(startDate: DateTime(start.year, start.month, start.day)),
    );
  }

  Future<void> setCycleLength(int days) async {
    await _updateProfile((current) => current.copyWith(cycleLength: days));
  }

  Future<void> shiftStartDateByDays(int days) async {
    final current = _dateOnly(_profile.startDate);
    await _updateProfile(
      (profile) => profile.copyWith(startDate: current.add(Duration(days: days))),
    );
  }

  Future<void> setAutoSchedule(bool value) async {
    await _updateProfile((current) => current.copyWith(autoSchedule: value));
  }

  Future<void> setNotifyDayBefore(bool value) async {
    await _updateProfile((current) => current.copyWith(notifyDayBefore: value));
  }

  Future<void> setNotifyDayBeforeTime(TimeOfDay value) async {
    await _updateProfile((current) => current.copyWith(notifyDayBeforeTime: value));
  }

  Future<void> setNotifyDayOf(bool value) async {
    await _updateProfile((current) => current.copyWith(notifyDayOf: value));
  }

  Future<void> setNotifyDayOfTime(TimeOfDay value) async {
    await _updateProfile((current) => current.copyWith(notifyDayOfTime: value));
  }

  Future<void> setNotifyInventoryAlert(bool value) async {
    await _updateProfile(
      (current) => current.copyWith(inventoryAlertEnabled: value),
    );
  }

  Future<void> setInventoryAlertTime(TimeOfDay value) async {
    await _updateProfile(
      (current) => current.copyWith(inventoryAlertTime: value),
    );
  }

  Future<void> setThemeColorIndex(int index) async {
    if (index < 0 || index >= _availableThemeColors.length) return;
    if (_profile.themeColorIndex == index) return;
    await _updateProfile(
      (current) => current.copyWith(themeColorIndex: index),
      rescheduleNotifications: false,
    );
  }

  Future<void> setShowInventory(bool value) async {
    await _updateProfile((current) => current.copyWith(showInventory: value));
  }

  Future<void> setInventoryCount(int? value) async {
    final sanitized = value == null
        ? null
        : value < 0
            ? 0
            : value;
    await _updateProfile(
      (current) => current.copyWith(inventoryCount: sanitized),
    );
  }

  Future<void> setInventoryThreshold(int value) async {
    await _updateProfile(
      (current) => current.copyWith(inventoryThreshold: value < 0 ? 0 : value),
    );
  }

  Future<void> dismissInventoryOnboarding() async {
    _inventoryOnboardingDismissed = true;
    await _prefs?.setBool(_inventoryOnboardingDismissedKey, true);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    await _updateProfile(
      (current) => current.copyWith(soundEnabled: value),
      rescheduleNotifications: false,
    );
  }

  Future<void> setShowSecondProfile(bool value) async {
    if (_showSecondProfile == value) return;
    _showSecondProfile = value;
    if (!_showSecondProfile && _selectedProfileIndex == 1) {
      _selectedProfileIndex = 0;
      await _rescheduleNotifications();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setProfileName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _updateProfile(
      (current) => current.copyWith(name: trimmed),
      rescheduleNotifications: false,
    );
  }

  Future<void> setLensType(String lensType) async {
    await _updateProfile(
      (current) => current.copyWith(lensType: lensType.trim().isEmpty ? current.lensType : lensType.trim()),
      rescheduleNotifications: false,
    );
  }

  Future<void> switchProfile(int index) async {
    if (index < 0 || index >= _profiles.length) return;
    if (index == 1 && !_profiles[1].isRegistered) return;
    if (_selectedProfileIndex == index) return;
    _selectedProfileIndex = index;
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> registerSecondProfile({
    required String primaryName,
    required String secondaryName,
  }) async {
    final trimmedPrimary = primaryName.trim();
    final trimmedSecondary = secondaryName.trim();
    if (trimmedSecondary.isEmpty) return;
    _profiles[0] = _profiles[0].copyWith(
      name: trimmedPrimary.isEmpty ? _profiles[0].name : trimmedPrimary,
    );
    _profiles[1] = ContactProfile.secondaryPlaceholder().copyWith(
      name: trimmedSecondary,
      themeColorIndex: _secondProfileDefaultColorIndex,
      isRegistered: true,
    );
    _profiles[1] = _profiles[1].autoAdvanced(_today());
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<ContactProfile?> _loadProfile(int index) async {
    final stored = _prefs?.getString('$_profileKeyPrefix$index');
    if (stored == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(stored);
      if (decoded is Map<String, dynamic>) {
        return ContactProfile.fromMap(decoded);
      }
      return ContactProfile.fromMap(Map<String, dynamic>.from(decoded as Map));
    } catch (_) {
      return null;
    }
  }

  Future<ContactProfile> _loadLegacyProfile() async {
    final startMillis = _prefs?.getInt(_startDateKey);
    final startDate = startMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startMillis)
        : DateTime.now();

    final storedThemeIndex = _prefs?.getInt(_themeColorIndexKey) ?? 0;
    int themeIndex;
    if (storedThemeIndex < 0) {
      themeIndex = 0;
    } else if (storedThemeIndex >= _availableThemeColors.length) {
      themeIndex = _availableThemeColors.length - 1;
    } else {
      themeIndex = storedThemeIndex;
    }

    return ContactProfile(
      name: 'コンタクト1',
      lensType: _prefs?.getString(_lensTypeKey) ?? 'コンタクト',
      cycleLength: _prefs?.getInt(_cycleKey) ?? twoWeekCycle,
      startDate: startDate,
      autoSchedule: _prefs?.getBool(_autoScheduleKey) ?? true,
      notifyDayBefore: _prefs?.getBool(_notifyDayBeforeKey) ?? true,
      notifyDayBeforeTime: ContactProfile._timeFromMinutes(
        _prefs?.getInt(_notifyDayBeforeTimeKey),
        const TimeOfDay(hour: 20, minute: 0),
      ),
      notifyDayOf: _prefs?.getBool(_notifyDayOfKey) ?? true,
      notifyDayOfTime: ContactProfile._timeFromMinutes(
        _prefs?.getInt(_notifyDayOfTimeKey),
        const TimeOfDay(hour: 7, minute: 0),
      ),
      themeColorIndex: themeIndex,
      inventoryAlertEnabled:
          _prefs?.getBool(_inventoryAlertEnabledKey) ?? true,
      inventoryAlertTime: _defaultInventoryAlertTime,
      showInventory: _prefs?.getBool(_showInventoryKey) ?? false,
      inventoryCount: (_prefs?.containsKey(_inventoryCountKey) ?? false)
          ? _prefs!.getInt(_inventoryCountKey)
          : null,
      inventoryThreshold: _prefs?.getInt(_inventoryThresholdKey) ?? 2,
      soundEnabled: _prefs?.getBool(_soundEnabledKey) ?? true,
      isRegistered: true,
    );
  }

  Future<void> _updateProfile(
    ContactProfile Function(ContactProfile current) updater, {
    bool rescheduleNotifications = true,
  }) async {
    _profiles[_selectedProfileIndex] =
        updater(_profiles[_selectedProfileIndex]).autoAdvanced(_today());
    await _persist();
    if (rescheduleNotifications) {
      await _rescheduleNotifications();
    }
    notifyListeners();
  }

  void _autoAdvanceAll() {
    final today = _today();
    for (var i = 0; i < _profiles.length; i++) {
      _profiles[i] = _profiles[i].autoAdvanced(today);
    }
  }

  Future<void> _persist() async {
    for (var i = 0; i < _profiles.length; i++) {
      await _prefs?.setString(
        '$_profileKeyPrefix$i',
        jsonEncode(_profiles[i].toMap()),
      );
    }
    await _prefs?.setInt(_selectedProfileIndexKey, _selectedProfileIndex);
    await _prefs?.setBool(
      _inventoryOnboardingDismissedKey,
      _inventoryOnboardingDismissed,
    );
    await _prefs?.setBool(_showSecondProfileKey, _showSecondProfile);
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _rescheduleNotifications() async {
    await _notificationsPlugin.cancel(_dayBeforeNotificationId);
    await _notificationsPlugin.cancel(_dayOfNotificationId);
    await _notificationsPlugin.cancel(_inventoryAlertNotificationId);

    final exchange = exchangeDate;
    final now = tz.TZDateTime.now(tz.local);

    if (_profile.inventoryAlertEnabled &&
        _profile.showInventory &&
        _profile.inventoryCount != null &&
        _profile.inventoryCount! <= _profile.inventoryThreshold) {
      final scheduled = _scheduledDateTime(
        exchange.subtract(const Duration(days: 3)),
        _profile.inventoryAlertTime,
      );

      if (scheduled.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          _inventoryAlertNotificationId,
          '在庫アラート',
          '在庫がお知らせ基準以下です。交換まであと3日です',
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'contact_lens_schedule',
              'Contact Lens Schedule',
              channelDescription: 'コンタクト交換のリマインダー通知',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    }

    if (_profile.notifyDayBefore) {
      final scheduled = _scheduledDateTime(
        exchange.subtract(const Duration(days: 1)),
        _profile.notifyDayBeforeTime,
      );
      if (scheduled.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          _dayBeforeNotificationId,
          'コンタクト交換のお知らせ',
          '明日でコンタクト交換です',
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'contact_lens_schedule',
              'Contact Lens Schedule',
              channelDescription: 'コンタクト交換のリマインダー通知',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    }

    if (_profile.notifyDayOf) {
      final scheduled = _scheduledDateTime(exchange, _profile.notifyDayOfTime);
      if (scheduled.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          _dayOfNotificationId,
          'コンタクト交換のお知らせ',
          '今日でコンタクト交換です',
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'contact_lens_schedule',
              'Contact Lens Schedule',
              channelDescription: 'コンタクト交換のリマインダー通知',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    }
  }

  tz.TZDateTime _scheduledDateTime(DateTime date, TimeOfDay time) {
    final location = tz.local;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final scheduled = tz.TZDateTime(
      location,
      dateOnly.year,
      dateOnly.month,
      dateOnly.day,
      time.hour,
      time.minute,
    );
    return scheduled;
  }

  Color _colorWithDefaultOpacity(int index) {
    final baseColor = _availableThemeColors[index];
    if (index == 0) {
      return baseColor.withOpacity(0.9);
    }
    return baseColor;
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AudioPlayer _audioPlayer;

  static const Color overdueColor = Color(0xE5BB5858);

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactLensState>();
    final themeColor = state.themeColor;
    final isOverdue = state.overdueDays > 0;
    final Color mainColor = isOverdue ? overdueColor : themeColor;
    final Color fadedColor = mainColor.withOpacity(0.2);
    final cycleLabel = state.cycleLabel;
    final daysRemaining = state.remainingDays;
    final daysOverdue = state.overdueDays;
    final startDate = state.startDate;
    final exchangeDate = state.exchangeDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final isBeforeStart = start.isAfter(today);
    final shouldShowExpiredWarning = !isBeforeStart && isOverdue;
    final chartSize = math.min(MediaQuery.of(context).size.width * 0.8, 320.0);
    final hasSecondProfile = state.hasSecondProfile;
    final showSecondProfile = state.showSecondProfile;
    final secondVisible = hasSecondProfile && showSecondProfile;
    final canShowSecondProfile = secondVisible;
    final inventoryCount = state.inventoryCount;
    final shouldShiftMainContent =
        canShowSecondProfile && state.shouldShowInventoryAlert;
    final mainContentOffset =
        shouldShiftMainContent ? const Offset(0, -24) : Offset.zero;

    return Scaffold(
      appBar: AppBar(
        title: const Text('コンタクト交換管理'),
        backgroundColor: themeColor,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: canShowSecondProfile ? 1 : 0,
                          child: canShowSecondProfile
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: ContactSwitcher(
                                    firstLabel: state.profileName(0),
                                    secondLabel: state.profileName(1),
                                    selectedIndex: state.selectedProfileIndex,
                                    color: themeColor,
                                    onSelected: (index) => state.switchProfile(index),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (canShowSecondProfile) const SizedBox(height: 20),
                        Center(
                          child: Transform.translate(
                            offset: mainContentOffset,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: chartSize,
                                  height: chartSize + 68,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        top: 0,
                                        left: 16,
                                        right: 16,
                                        child: SizedBox(
                                          height: 52,
                                          child: Align(
                                            alignment: Alignment.topLeft,
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    cycleLabel,
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 60,
                                        left: 0,
                                        right: 0,
                                        child: SizedBox(
                                          width: chartSize,
                                          height: chartSize,
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween<double>(
                                              begin: 0,
                                              end: state.progress,
                                            ),
                                            duration: const Duration(milliseconds: 400),
                                            curve: Curves.easeInOut,
                                            builder: (context, animatedProgress, _) {
                                              return CustomPaint(
                                                size: Size(chartSize, chartSize),
                                                painter: CircularProgressPainter(
                                                  progress: animatedProgress,
                                                  color: mainColor,
                                                  backgroundColor: fadedColor,
                                                  isOverdue: isOverdue,
                                                ),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      if (isBeforeStart)
                                                        Text(
                                                          '使用開始前です',
                                                          style: TextStyle(
                                                            fontSize: 28,
                                                            fontWeight: FontWeight.w700,
                                                            color: themeColor,
                                                          ),
                                                        )
                                                      else if (shouldShowExpiredWarning)
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Icon(
                                                              Icons.error_outline,
                                                              color: overdueColor,
                                                              size: 32,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Flexible(
                                                              child: Text(
                                                                '使用期限が過ぎています',
                                                                textAlign: TextAlign.center,
                                                                style: TextStyle(
                                                                  fontSize: 24,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: overdueColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      else
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                          children: [
                                                            Text(
                                                              '交換まで',
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              isOverdue
                                                                  ? '$daysOverdue'
                                                                  : '$daysRemaining',
                                                              style: TextStyle(
                                                                fontSize: 56,
                                                                fontWeight: FontWeight.bold,
                                                                color: isOverdue
                                                                    ? overdueColor
                                                                    : themeColor,
                                                                height: 1,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '日',
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      const SizedBox(height: 4),
                                                      if (!shouldShowExpiredWarning)
                                                        Text(
                                                          '${formatJapaneseDateWithWeekday(startDate)} ～ ${formatJapaneseDateWithWeekday(exchangeDate)}',
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () => _onExchangeButtonPressed(state),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: themeColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: const Text(
                                      'レンズを交換する',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (state.shouldShowInventoryOnboarding) ...[
                          const SizedBox(height: 20),
                          InventoryOnboardingCard(
                            accentColor: themeColor,
                            onSetup: () => _startInventorySetup(state),
                            onDismiss: () => state.dismissInventoryOnboarding(),
                          ),
                        ],
                        if (state.shouldShowInventoryAlert) ...[
                          const SizedBox(height: 20),
                          if (!secondVisible) const Spacer(),
                          Transform.translate(
                            offset: const Offset(0, -50),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange[300]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '在庫が残り ${inventoryCount ?? 0} 個です。お早めにご用意ください',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange[900],
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          const SizedBox(height: 72),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 14,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 2),
                  child: IconButton(
                    iconSize: 40,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    splashRadius: 26,
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.black87,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startInventorySetup(ContactLensState state) async {
    final saved = await showInventoryPicker(
      context,
      state,
      isCurrentInventory: true,
    );

    if (!saved) {
      return;
    }

    if (!mounted) return;

    await state.setShowInventory(true);
    await state.dismissInventoryOnboarding();
  }

  void _showExchangeModal(ContactLensState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => ExchangeModalSheet(
        cycleDays: state.cycleLength,
        themeColor: state.themeColor,
        onTodayExchange: () async {
          Navigator.pop(bottomSheetContext);
          await _recordExchangeToday(state);
        },
        onDateSelected: (selectedDate) async {
          Navigator.pop(bottomSheetContext);
          await _recordExchangeOnSelectedDate(state, selectedDate);
        },
      ),
    );
  }

  Future<void> _onExchangeButtonPressed(ContactLensState state) async {
    if (state.showInventory && (state.inventoryCount == null || state.inventoryCount! <= 0)) {
      final updated = await showInventoryPicker(
        context,
        state,
        isCurrentInventory: true,
      );

      if (!updated || !mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    _showExchangeModal(state);
  }

  Future<void> _recordExchangeOnSelectedDate(
    ContactLensState state,
    DateTime selected,
  ) async {
    final inventoryBefore = state.inventoryCount;
    await state.recordExchangeOn(selected);
    if (inventoryBefore != null && inventoryBefore > 0) {
      await state.setInventoryCount(inventoryBefore - 1);
    }
    if (!mounted) {
      return;
    }

    await _playExchangeSound(state);

    final exchangePreview = selected.add(Duration(days: state.cycleLength));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '開始日: ${_formatDate(selected)}\n交換予定日: ${_formatDate(exchangePreview)}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _recordExchangeToday(ContactLensState state) async {
    final inventoryBefore = state.inventoryCount;
    await state.recordExchangeToday();
    if (inventoryBefore != null && inventoryBefore > 0) {
      await state.setInventoryCount(inventoryBefore - 1);
    }
    if (!mounted) return;
    await _playExchangeSound(state);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('開始日を本日にリセットしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _playExchangeSound(ContactLensState state) async {
    if (!state.soundEnabled) return;
    await _audioPlayer.play(
      AssetSource('sounds/決定ボタンを押す53.mp3'),
    );
  }

  String _formatDate(DateTime date) {
    return formatJapaneseDateWithWeekday(date);
  }
}

class InventoryOnboardingCard extends StatelessWidget {
  const InventoryOnboardingCard({
    super.key,
    required this.onSetup,
    required this.onDismiss,
    required this.accentColor,
  });

  final VoidCallback onSetup;
  final VoidCallback onDismiss;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'コンタクトの在庫管理',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '残り個数のアラートが使えます',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text(
                    '在庫を設定する',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('今回はしない'),
            ),
          ),
        ],
      ),
    );
  }
}

class ContactSwitcher extends StatelessWidget {
  const ContactSwitcher({
    super.key,
    required this.firstLabel,
    required this.secondLabel,
    required this.selectedIndex,
    required this.color,
    required this.onSelected,
  });

  final String firstLabel;
  final String secondLabel;
  final int selectedIndex;
  final Color color;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(firstLabel, 0, true),
          _buildSegment(secondLabel, 1, false),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, int index, bool isFirst) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onSelected(index),
      borderRadius: BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(14) : Radius.zero,
        right: isFirst ? Radius.zero : const Radius.circular(14),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(14) : Radius.zero,
            right: isFirst ? Radius.zero : const Radius.circular(14),
          ),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExchangeModalSheet extends StatefulWidget {
  const ExchangeModalSheet({
    super.key,
    required this.cycleDays,
    required this.themeColor,
    required this.onTodayExchange,
    required this.onDateSelected,
  });

  final int cycleDays;
  final Color themeColor;
  final VoidCallback onTodayExchange;
  final Function(DateTime) onDateSelected;

  @override
  State<ExchangeModalSheet> createState() => _ExchangeModalSheetState();
}

class _ExchangeModalSheetState extends State<ExchangeModalSheet> {
  bool _showDatePicker = false;
  DateTime? _previewStartDate;
  DateTime? _previewExchangeDate;

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  void _confirmDateSelection() {
    if (_previewStartDate != null) {
      widget.onDateSelected(_previewStartDate!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(maxHeight: _showDatePicker ? maxHeight : 420),
      child: SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Text(
                'レンズ交換を記録',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_showDatePicker && _previewStartDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.themeColor.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '選択プレビュー',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '開始日',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatDate(_previewStartDate!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: widget.themeColor,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '交換予定日',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _previewExchangeDate != null
                                      ? _formatDate(_previewExchangeDate!)
                                      : '---',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: widget.themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_showDatePicker) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTodayExchange,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: widget.themeColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            '今日交換した',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showDatePicker = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Center(
                          child: Text(
                            '予定日を選ぶ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'キャンセル',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context)
                          .colorScheme
                          .copyWith(primary: widget.themeColor),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _previewStartDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onDateChanged: (date) {
                        setState(() {
                          _previewStartDate = date;
                          _previewExchangeDate =
                              date.add(Duration(days: widget.cycleDays));
                        });
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _showDatePicker = false;
                                _previewStartDate = null;
                                _previewExchangeDate = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Center(
                                child: Text(
                                  'キャンセル',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _confirmDateSelection,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: widget.themeColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text(
                                  '完了',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String formatJapaneseDateWithWeekday(DateTime date) {
  final month = date.month.toString();
  final day = date.day.toString().padLeft(2, '0');
  final weekday = getWeekdayLabel(date);
  return '$month月$day日($weekday)';
}

String getWeekdayLabel(DateTime date) {
  const weekDays = ['月', '火', '水', '木', '金', '土', '日'];
  return weekDays[date.weekday - 1];
}

class CircularProgressPainter extends CustomPainter {
  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.isOverdue = false,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final bool isOverdue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 22.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final progressColor = isOverdue ? _HomeScreenState.overdueColor : color;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.isOverdue != isOverdue;
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactLensState>(
      builder: (context, state, _) {
        final cyclePeriod = state.cycleLength == ContactLensState.oneDayCycle
            ? '1day'
            : state.cycleLength == ContactLensState.oneMonthCycle
                ? '1month'
                : '2week';
        final themeColor = state.themeColor;
        const lensTypes = ['コンタクト', 'カラコン', '右', '左'];
        final hasSecondProfile = state.hasSecondProfile;
        final showSecondProfile = state.showSecondProfile;
        final canShowSecondProfile = hasSecondProfile && showSecondProfile;
        final secondaryProfileName = state.profileName(1);
        final shouldShowContactInfo =
            canShowSecondProfile && secondaryProfileName.trim().isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('設定'),
            backgroundColor: themeColor,
            elevation: 0,
          ),
          body: ListView(
            children: [
              if (hasSecondProfile) ...[
                _buildSectionHeader('コンタクト情報'),
                _buildSwitchTile(
                  title: '2つ目のコンタクトを表示',
                  value: showSecondProfile,
                  activeColor: themeColor,
                  onChanged: (value) {
                    state.setShowSecondProfile(value);
                  },
                ),
                if (shouldShowContactInfo) ...[
                  ListTile(
                    title: const Text('コンタクト名'),
                    subtitle: Text(state.currentProfileName),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                    onTap: () => _showNameEditDialog(context, state),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'レンズ種別',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final type in lensTypes)
                              ChoiceChip(
                                label: Text(type),
                                selected: state.currentLensType == type,
                                selectedColor: themeColor.withOpacity(0.15),
                                onSelected: (_) => state.setLensType(type),
                                labelStyle: TextStyle(
                                  color: state.currentLensType == type
                                      ? themeColor
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 32),
              ],
              _buildSectionHeader('交換周期'),
              _buildRadioTile(
                title: '2week（14日）',
                value: '2week',
                groupValue: cyclePeriod,
                activeColor: themeColor,
                onChanged: (value) {
                  if (value == '2week') {
                    state.setCycleLength(ContactLensState.twoWeekCycle);
                  } else if (value == '1month') {
                    state.setCycleLength(ContactLensState.oneMonthCycle);
                  } else if (value == '1day') {
                    state.setCycleLength(ContactLensState.oneDayCycle);
                  }
                },
              ),
              _buildRadioTile(
                title: '1day（1日）',
                value: '1day',
                groupValue: cyclePeriod,
                activeColor: themeColor,
                onChanged: (value) {
                  if (value == '2week') {
                    state.setCycleLength(ContactLensState.twoWeekCycle);
                  } else if (value == '1month') {
                    state.setCycleLength(ContactLensState.oneMonthCycle);
                  } else if (value == '1day') {
                    state.setCycleLength(ContactLensState.oneDayCycle);
                  }
                },
              ),
              _buildRadioTile(
                title: '1month（30日）',
                value: '1month',
                groupValue: cyclePeriod,
                activeColor: themeColor,
                onChanged: (value) {
                  if (value == '2week') {
                    state.setCycleLength(ContactLensState.twoWeekCycle);
                  } else if (value == '1month') {
                    state.setCycleLength(ContactLensState.oneMonthCycle);
                  }
                },
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '開始日',
                      style: TextStyle(fontSize: 16),
                    ),
                    Row(
                      children: [
                        _StartDateButton(
                          icon: Icons.remove,
                          onTap: () => state.shiftStartDateByDays(-1),
                          color: themeColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatSimpleDate(state.startDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StartDateButton(
                          icon: Icons.add,
                          onTap: () => state.shiftStartDateByDays(1),
                          color: themeColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              _buildSectionHeader('通知'),
              _buildSwitchTile(
                title: '前日通知',
                subtitle:
                    state.notifyDayBefore ? _formatTime(state.notifyDayBeforeTime) : null,
                value: state.notifyDayBefore,
                activeColor: themeColor,
                onChanged: (value) {
                  state.setNotifyDayBefore(value);
                },
              ),
              if (state.notifyDayBefore)
                _buildTimeTile(
                  context: context,
                  title: '前日通知時刻',
                  time: state.notifyDayBeforeTime,
                  onTap: () => _selectTime(
                    context,
                    state,
                    type: NotificationTimeType.dayBefore,
                  ),
                ),
              _buildSwitchTile(
                title: '当日通知',
                subtitle: state.notifyDayOf ? _formatTime(state.notifyDayOfTime) : null,
                value: state.notifyDayOf,
                activeColor: themeColor,
                onChanged: (value) {
                  state.setNotifyDayOf(value);
                },
              ),
              if (state.notifyDayOf)
                _buildTimeTile(
                  context: context,
                  title: '当日通知時刻',
                  time: state.notifyDayOfTime,
                  onTap: () => _selectTime(
                    context,
                    state,
                    type: NotificationTimeType.dayOf,
                  ),
                ),
              _buildSwitchTile(
                title: '在庫アラート通知',
                subtitle:
                    'お知らせ基準以下＆交換まで3日で通知 (${_formatTime(state.inventoryAlertTime)})',
                value: state.notifyInventoryAlert,
                activeColor: themeColor,
                onChanged: (value) {
                  state.setNotifyInventoryAlert(value);
                },
              ),
              if (state.notifyInventoryAlert)
                _buildTimeTile(
                  context: context,
                  title: '在庫アラート通知時刻',
                  time: state.inventoryAlertTime,
                  onTap: () => _selectTime(
                    context,
                    state,
                    type: NotificationTimeType.inventoryAlert,
                  ),
                ),
              const Divider(height: 32),
              _buildSectionHeader('コンタクトの在庫'),
              _buildSwitchTile(
                title: '在庫数を表示',
                value: state.showInventory,
                activeColor: themeColor,
                onChanged: (value) {
                  state.setShowInventory(value);
                },
              ),
              if (state.showInventory) ...[
                ListTile(
                  title: const Text('現在の在庫'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.inventoryCount == null
                            ? '未設定'
                            : '${state.inventoryCount} 個',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                  onTap: () => showInventoryPicker(
                    context,
                    state,
                    isCurrentInventory: true,
                  ),
                ),
                ListTile(
                  title: const Text('お知らせ基準'),
                  subtitle: Text('${state.inventoryThreshold} 個以下で通知'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${state.inventoryThreshold} 個',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                  onTap: () => showInventoryPicker(
                    context,
                    state,
                    isCurrentInventory: false,
                  ),
                ),
              ],
              const Divider(height: 32),
              _buildSectionHeader('自動更新'),
              _buildSwitchTile(
                title: '自動スケジュール更新',
                subtitle: '交換日到来時に次周期へ自動更新',
                value: state.autoSchedule,
                activeColor: themeColor,
                onChanged: (value) {
                  state.setAutoSchedule(value);
                },
              ),
              if (!hasSecondProfile)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showSecondContactDialog(context, state),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      '2つ目のコンタクトを登録',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const Divider(height: 32),
              _buildSectionHeader('効果音'),
              _buildSwitchTile(
                title: '効果音',
                value: state.soundEnabled,
                activeColor: themeColor,
                onChanged: (value) {
                  state.setSoundEnabled(value);
                },
              ),
              const Divider(height: 32),
              _buildSectionHeader('テーマカラー'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 5,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 0; i < state.availableThemeColors.length; i++)
                          _buildColorOption(
                            color: state.colorForIndex(i),
                            isSelected: i == state.themeColorIndex,
                            onTap: () => state.setThemeColorIndex(i),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNameEditDialog(
    BuildContext context,
    ContactLensState state,
  ) async {
    final controller = TextEditingController(text: state.currentProfileName);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('コンタクト名を編集'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '名前を入力',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      await state.setProfileName(result.trim());
    }
  }

  Future<void> _showSecondContactDialog(
    BuildContext context,
    ContactLensState state,
  ) async {
    final primaryController = TextEditingController(text: state.profileName(0));
    final secondaryController = TextEditingController(text: state.profileName(1));

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('2つ目のコンタクトを登録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: primaryController,
                decoration: const InputDecoration(
                  labelText: '1つ目の名前',
                  hintText: '例：右目 / 日常用',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secondaryController,
                decoration: const InputDecoration(
                  labelText: '2つ目の名前',
                  hintText: '例：左目 / 仕事用',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final primaryName = primaryController.text.trim();
                final secondaryName = secondaryController.text.trim();
                if (secondaryName.isEmpty) return;
                Navigator.of(dialogContext).pop(
                  {'primary': primaryName, 'secondary': secondaryName},
                );
              },
              child: const Text('登録'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await state.registerSecondProfile(
        primaryName: result['primary'] ?? '',
        secondaryName: result['secondary'] ?? '',
      );
    }
  }

  Future<void> _selectTime(
    BuildContext context,
    ContactLensState state, {
    required NotificationTimeType type,
  }) async {
    late TimeOfDay initialTime;
    switch (type) {
      case NotificationTimeType.dayBefore:
        initialTime = state.notifyDayBeforeTime;
        break;
      case NotificationTimeType.dayOf:
        initialTime = state.notifyDayOfTime;
        break;
      case NotificationTimeType.inventoryAlert:
        initialTime = state.inventoryAlertTime;
        break;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (dialogContext, child) {
        return Theme(
          data: Theme.of(dialogContext).copyWith(
            colorScheme: ColorScheme.light(
              primary: state.themeColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      switch (type) {
        case NotificationTimeType.dayBefore:
          await state.setNotifyDayBeforeTime(picked);
          break;
        case NotificationTimeType.dayOf:
          await state.setNotifyDayOfTime(picked);
          break;
        case NotificationTimeType.inventoryAlert:
          await state.setInventoryAlertTime(picked);
          break;
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatSimpleDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String value,
    required String groupValue,
    required Color activeColor,
    required ValueChanged<String?> onChanged,
  }) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      activeColor: activeColor,
      onChanged: onChanged,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      activeColor: activeColor,
      onChanged: onChanged,
    );
  }

  Widget _buildTimeTile({
    required BuildContext context,
    required String title,
    required TimeOfDay time,
    required Future<void> Function() onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(time),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
      onTap: () {
        onTap();
      },
    );
  }

  Widget _buildColorOption({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 32,
              )
            : null,
      ),
    );
  }

}

class _StartDateButton extends StatelessWidget {
  const _StartDateButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

Future<bool> showInventoryPicker(
  BuildContext context,
  ContactLensState state, {
  required bool isCurrentInventory,
  int? initialValue,
}) async {
  final baseValue = initialValue ??
      (isCurrentInventory ? state.inventoryCount ?? 0 : state.inventoryThreshold);
  final startingValue = baseValue < 0 ? 0 : baseValue;
  final maxValue = math.max(startingValue, 100);
  final maxCount = maxValue is int ? maxValue : maxValue.toInt();
  final clampedInitial = startingValue.clamp(0, maxCount);
  int selectedValue = clampedInitial is int ? clampedInitial : clampedInitial.toInt();
  var saved = false;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return Container(
        height: 300,
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('キャンセル'),
                  ),
                  Text(
                    isCurrentInventory ? '現在の在庫' : 'お知らせ基準',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (isCurrentInventory) {
                        await state.setInventoryCount(selectedValue);
                      } else {
                        await state.setInventoryThreshold(selectedValue);
                      }
                      saved = true;
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    },
                    child: const Text('完了'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(
                  initialItem: selectedValue,
                ),
                onSelectedItemChanged: (index) {
                  selectedValue = index;
                },
                children: List.generate(
                  maxCount + 1,
                  (index) => Center(
                    child: Text(
                      '$index 個',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  return saved;
}
