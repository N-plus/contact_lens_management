import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

class ContactLensState extends ChangeNotifier {
  ContactLensState();

  static const _cycleKey = 'cycleLength';
  static const _startDateKey = 'startDate';
  static const _autoScheduleKey = 'autoSchedule';
  static const _notifyDayBeforeKey = 'notifyDayBefore';
  static const _notifyDayBeforeTimeKey = 'notifyDayBeforeTime';
  static const _notifyDayOfKey = 'notifyDayOf';
  static const _notifyDayOfTimeKey = 'notifyDayOfTime';
  static const _themeColorIndexKey = 'themeColorIndex';
  static const _themeOpacityKey = 'themeOpacity';
  static const _showInventoryKey = 'showInventory';
  static const _inventoryCountKey = 'inventoryCount';
  static const _inventoryThresholdKey = 'inventoryThreshold';

  static const int twoWeekCycle = 14;
  static const int oneMonthCycle = 30;

  static const int _dayBeforeNotificationId = 1001;
  static const int _dayOfNotificationId = 1002;

  static const List<Color> _availableThemeColors = <Color>[
    Color(0xFF2F80ED),
    Color(0xFF27AE60),
    Color(0xFFF2994A),
    Color(0xFF9B51E0),
    Color(0xFFEB5757),
  ];

  SharedPreferences? _prefs;

  int _cycleLength = twoWeekCycle;
  DateTime _startDate = DateTime.now();
  bool _autoSchedule = true;
  bool _notifyDayBefore = true;
  TimeOfDay _notifyDayBeforeTime = const TimeOfDay(hour: 20, minute: 0);
  bool _notifyDayOf = true;
  TimeOfDay _notifyDayOfTime = const TimeOfDay(hour: 7, minute: 0);
  int _themeColorIndex = 0;
  double _themeOpacity = 1.0;
  bool _showInventory = false;
  int _inventoryCount = 0;
  int _inventoryThreshold = 2;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final storedStart = _prefs?.getInt(_startDateKey);
    if (storedStart != null) {
      _startDate = DateTime.fromMillisecondsSinceEpoch(storedStart);
    } else {
      _startDate = DateTime.now();
    }

    _cycleLength = _prefs?.getInt(_cycleKey) ?? twoWeekCycle;
    _autoSchedule = _prefs?.getBool(_autoScheduleKey) ?? true;
    _notifyDayBefore = _prefs?.getBool(_notifyDayBeforeKey) ?? true;
    _notifyDayBeforeTime = _loadTimeOfDay(
      _prefs?.getInt(_notifyDayBeforeTimeKey),
      const TimeOfDay(hour: 20, minute: 0),
    );
    _notifyDayOf = _prefs?.getBool(_notifyDayOfKey) ?? true;
    _notifyDayOfTime = _loadTimeOfDay(
      _prefs?.getInt(_notifyDayOfTimeKey),
      const TimeOfDay(hour: 7, minute: 0),
    );
    final storedThemeIndex = _prefs?.getInt(_themeColorIndexKey) ?? 0;
    if (storedThemeIndex < 0) {
      _themeColorIndex = 0;
    } else if (storedThemeIndex >= _availableThemeColors.length) {
      _themeColorIndex = _availableThemeColors.length - 1;
    } else {
      _themeColorIndex = storedThemeIndex;
    }
    _themeOpacity = (_prefs?.getDouble(_themeOpacityKey) ?? 1.0)
        .clamp(0.1, 1.0)
        .toDouble();
    _showInventory = _prefs?.getBool(_showInventoryKey) ?? false;
    _inventoryCount = _prefs?.getInt(_inventoryCountKey) ?? 0;
    _inventoryThreshold = _prefs?.getInt(_inventoryThresholdKey) ?? 2;

    _autoAdvanceIfNeeded();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  int get cycleLength => _cycleLength;
  DateTime get startDate => _startDate;
  DateTime get exchangeDate => _startDate.add(Duration(days: _cycleLength));
  bool get autoSchedule => _autoSchedule;
  bool get notifyDayBefore => _notifyDayBefore;
  TimeOfDay get notifyDayBeforeTime => _notifyDayBeforeTime;
  bool get notifyDayOf => _notifyDayOf;
  TimeOfDay get notifyDayOfTime => _notifyDayOfTime;
  Color get themeColor =>
      _availableThemeColors[_themeColorIndex].withOpacity(_themeOpacity);
  int get themeColorIndex => _themeColorIndex;
  double get themeOpacity => _themeOpacity;
  bool get showInventory => _showInventory;
  int get inventoryCount => _inventoryCount;
  int get inventoryThreshold => _inventoryThreshold;

  List<Color> get availableThemeColors => List.unmodifiable(_availableThemeColors);

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
    final total = _cycleLength;
    if (total == 0) {
      return 0;
    }
    final today = _today();
    final elapsed = today.difference(_dateOnly(_startDate)).inDays;
    final clamped = elapsed.clamp(0, total).toDouble();
    return clamped / total;
  }

  bool get shouldShowInventoryAlert =>
      _showInventory && _inventoryCount <= _inventoryThreshold;

  Future<void> recordExchangeToday() async {
    _startDate = DateTime.now();
    _autoAdvanceIfNeeded();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> recordExchangeOn(DateTime start) async {
    _startDate = DateTime(start.year, start.month, start.day);
    _autoAdvanceIfNeeded();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> setCycleLength(int days) async {
    if (_cycleLength == days) return;
    _cycleLength = days;
    _autoAdvanceIfNeeded();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> shiftStartDateByDays(int days) async {
    final current = _dateOnly(_startDate);
    _startDate = current.add(Duration(days: days));
    _autoAdvanceIfNeeded();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> setAutoSchedule(bool value) async {
    _autoSchedule = value;
    _autoAdvanceIfNeeded();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> setNotifyDayBefore(bool value) async {
    _notifyDayBefore = value;
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> setNotifyDayBeforeTime(TimeOfDay value) async {
    _notifyDayBeforeTime = value;
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> setNotifyDayOf(bool value) async {
    _notifyDayOf = value;
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> setNotifyDayOfTime(TimeOfDay value) async {
    _notifyDayOfTime = value;
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> setThemeColorIndex(int index) async {
    if (index < 0 || index >= _availableThemeColors.length) return;
    if (_themeColorIndex == index) return;
    _themeColorIndex = index;
    await _persist();
    notifyListeners();
  }

  Future<void> setThemeOpacity(double value) async {
    final normalized = value.clamp(0.1, 1.0).toDouble();
    if (_themeOpacity == normalized) return;
    _themeOpacity = normalized;
    await _persist();
    notifyListeners();
  }

  Future<void> setShowInventory(bool value) async {
    _showInventory = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setInventoryCount(int value) async {
    _inventoryCount = value < 0 ? 0 : value;
    await _persist();
    notifyListeners();
  }

  Future<void> setInventoryThreshold(int value) async {
    _inventoryThreshold = value < 0 ? 0 : value;
    await _persist();
    notifyListeners();
  }

  TimeOfDay _loadTimeOfDay(int? stored, TimeOfDay fallback) {
    if (stored == null) {
      return fallback;
    }
    final hour = stored ~/ 60;
    final minute = stored % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _persist() async {
    await _prefs?.setInt(_startDateKey, _startDate.millisecondsSinceEpoch);
    await _prefs?.setInt(_cycleKey, _cycleLength);
    await _prefs?.setBool(_autoScheduleKey, _autoSchedule);
    await _prefs?.setBool(_notifyDayBeforeKey, _notifyDayBefore);
    await _prefs?.setInt(
      _notifyDayBeforeTimeKey,
      _notifyDayBeforeTime.hour * 60 + _notifyDayBeforeTime.minute,
    );
    await _prefs?.setBool(_notifyDayOfKey, _notifyDayOf);
    await _prefs?.setInt(
      _notifyDayOfTimeKey,
      _notifyDayOfTime.hour * 60 + _notifyDayOfTime.minute,
    );
    await _prefs?.setInt(_themeColorIndexKey, _themeColorIndex);
    await _prefs?.setDouble(_themeOpacityKey, _themeOpacity);
    await _prefs?.setBool(_showInventoryKey, _showInventory);
    await _prefs?.setInt(_inventoryCountKey, _inventoryCount);
    await _prefs?.setInt(_inventoryThresholdKey, _inventoryThreshold);
  }

  void _autoAdvanceIfNeeded() {
    if (!_autoSchedule) {
      return;
    }

    var start = _dateOnly(_startDate);
    var nextExchange = start.add(Duration(days: _cycleLength));
    final today = _today();

    while (!today.isBefore(nextExchange)) {
      start = nextExchange;
      nextExchange = start.add(Duration(days: _cycleLength));
    }

    if (start != _dateOnly(_startDate)) {
      _startDate = start;
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _rescheduleNotifications() async {
    await _notificationsPlugin.cancel(_dayBeforeNotificationId);
    await _notificationsPlugin.cancel(_dayOfNotificationId);

    final exchange = exchangeDate;
    final now = tz.TZDateTime.now(tz.local);

    if (_notifyDayBefore) {
      final scheduled = _scheduledDateTime(
        exchange.subtract(const Duration(days: 1)),
        _notifyDayBeforeTime,
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

    if (_notifyDayOf) {
      final scheduled = _scheduledDateTime(exchange, _notifyDayOfTime);
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
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactLensState>();
    final themeColor = state.themeColor;
    final isOverdue = state.overdueDays > 0;
    final Color mainColor = isOverdue ? Colors.red : themeColor;
    final Color fadedColor = mainColor.withOpacity(0.2);
    final daysRemaining = state.remainingDays;
    final daysOverdue = state.overdueDays;
    final startDate = state.startDate;
    final exchangeDate = state.exchangeDate;
    final chartSize = math.min(MediaQuery.of(context).size.width * 0.8, 320.0);

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
            Positioned(
              top: 8,
              right: 16,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                  child: const SizedBox.square(
                    dimension: 52,
                    child: Center(
                      child: Icon(
                        Icons.settings,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -50),
                      child: SizedBox(
                        width: chartSize,
                        height: chartSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size(chartSize, chartSize),
                              painter: CircularProgressPainter(
                                progress: state.progress,
                                color: mainColor,
                                backgroundColor: fadedColor,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                        isOverdue ? '$daysOverdue' : '$daysRemaining',
                                        style: TextStyle(
                                          fontSize: 56,
                                          fontWeight: FontWeight.bold,
                                          color: isOverdue ? Colors.red : themeColor,
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _showExchangeModal(state),
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
                    if (state.shouldShowInventoryAlert) ...[
                      const SizedBox(height: 20),
                      Container(
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
                                '在庫が残り ${state.inventoryCount} 個です。お早めにご用意ください',
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
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _recordExchangeOnSelectedDate(
    ContactLensState state,
    DateTime selected,
  ) async {
    final inventoryBefore = state.inventoryCount;
    await state.recordExchangeOn(selected);
    if (inventoryBefore > 0) {
      await state.setInventoryCount(inventoryBefore - 1);
    }
    if (!mounted) {
      return;
    }

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
    if (inventoryBefore > 0) {
      await state.setInventoryCount(inventoryBefore - 1);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('開始日を本日にリセットしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDate(ContactLensState state) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ja'),
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

    if (selected != null) {
      final inventoryBefore = state.inventoryCount;
      await state.recordExchangeOn(selected);
      if (inventoryBefore > 0) {
        await state.setInventoryCount(inventoryBefore - 1);
      }
      if (!mounted) {
        return;
      }

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
  }

  String _formatDate(DateTime date) {
    return formatJapaneseDateWithWeekday(date);
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

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ja'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.themeColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _previewStartDate = selected;
        _previewExchangeDate = selected.add(Duration(days: widget.cycleDays));
      });
    }
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
                        _selectDate();
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

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

    final progressPaint = Paint()
      ..color = color
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
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactLensState>(
      builder: (context, state, _) {
        final cyclePeriod =
            state.cycleLength == ContactLensState.oneMonthCycle ? '1month' : '2week';
        final themeColor = state.themeColor;

        return Scaffold(
          appBar: AppBar(
            title: const Text('設定'),
            backgroundColor: themeColor,
            elevation: 0,
          ),
          body: ListView(
            children: [
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
                  onTap: () => _selectTime(context, state, isDayBefore: true),
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
                  onTap: () => _selectTime(context, state, isDayBefore: false),
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
                            color: state.availableThemeColors[i]
                                .withOpacity(state.themeOpacity),
                            isSelected: i == state.themeColorIndex,
                            onTap: () => state.setThemeColorIndex(i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildOpacitySlider(state),
                  ],
                ),
              ),
              const Divider(height: 32),
              _buildSectionHeader('在庫'),
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
                        '${state.inventoryCount} 個',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                  onTap: () => _showInventoryPicker(
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
                  onTap: () => _showInventoryPicker(
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
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    ContactLensState state, {
    required bool isDayBefore,
  }) async {
    final initialTime = isDayBefore ? state.notifyDayBeforeTime : state.notifyDayOfTime;

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
      if (isDayBefore) {
        await state.setNotifyDayBeforeTime(picked);
      } else {
        await state.setNotifyDayOfTime(picked);
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

  Future<void> _showInventoryPicker(
    BuildContext context,
    ContactLensState state, {
    required bool isCurrentInventory,
  }) async {
    final initialValue = isCurrentInventory ? state.inventoryCount : state.inventoryThreshold;
    final maxValue = math.max(initialValue, 100);
    final maxCount = maxValue is int ? maxValue : maxValue.toInt();
    final clampedInitial = initialValue.clamp(0, maxCount);
    int selectedValue = clampedInitial is int ? clampedInitial : clampedInitial.toInt();

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

  Widget _buildOpacitySlider(ContactLensState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '不透明度',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '${(state.themeOpacity * 100).round()}%',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        Slider(
          min: 0.1,
          max: 1.0,
          divisions: 18,
          value: state.themeOpacity,
          activeColor: state.themeColor,
          onChanged: (value) {
            state.setThemeOpacity(value);
          },
        ),
      ],
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
