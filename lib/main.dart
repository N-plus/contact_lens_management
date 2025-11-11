import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: state.themeColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
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
  Color get themeColor => _availableThemeColors[_themeColorIndex];
  int get themeColorIndex => _themeColorIndex;
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('yyyy/MM/dd');

    return Consumer<ContactLensState>(
      builder: (context, state, _) {
        final remaining = state.remainingDays;
        final overdue = state.overdueDays;
        final exchangeDate = state.exchangeDate;

        return Scaffold(
          appBar: AppBar(
            title: const Text('レンズ交換スケジュール'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              )
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      height: 240,
                      width: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: state.progress,
                              strokeWidth: 12,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                overdue > 0
                                    ? '交換超過 $overdue 日'
                                    : '残り$remaining日',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '開始日 ${dateFormatter.format(state.startDate)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '交換日 ${dateFormatter.format(exchangeDate)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.shouldShowInventoryAlert)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '在庫が残り ${state.inventoryCount} 個です。お早めにご用意ください',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  onPressed: () => _showExchangeSheet(context),
                  icon: const Icon(Icons.refresh),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'レンズを交換する',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showExchangeSheet(BuildContext context) async {
    final state = context.read<ContactLensState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'レンズ交換を記録',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('今日交換した'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  state.recordExchangeToday();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('開始日を本日にリセットしました'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_available),
                title: const Text('予定日を選ぶ'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DateSelectionPage(),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('キャンセル'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class DateSelectionPage extends StatefulWidget {
  const DateSelectionPage({super.key});

  @override
  State<DateSelectionPage> createState() => _DateSelectionPageState();
}

class _DateSelectionPageState extends State<DateSelectionPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _selectedDate = tomorrow;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactLensState>();
    final exchangeDate = _selectedDate.add(Duration(days: state.cycleLength));
    final formatter = DateFormat('yyyy/MM/dd');

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final firstSelectable = todayOnly.add(const Duration(days: 1));
    return Scaffold(
      appBar: AppBar(
        title: const Text('交換予定日を選択'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '開始日: ${formatter.format(_selectedDate)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '交換予定日: ${formatter.format(exchangeDate)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: firstSelectable,
                lastDate: firstSelectable.add(const Duration(days: 365 * 2)),
                selectableDayPredicate: (date) {
                  final selectedDay = DateTime(date.year, date.month, date.day);
                  return selectedDay.isAfter(todayOnly);
                },
                onDateChanged: (value) {
                  setState(() {
                    _selectedDate = DateTime(value.year, value.month, value.day);
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await state.recordExchangeOn(_selectedDate);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: Consumer<ContactLensState>(
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '交換周期',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: ContactLensState.twoWeekCycle, label: Text('2week')),
                  ButtonSegment<int>(value: ContactLensState.oneMonthCycle, label: Text('1month')),
                ],
                selected: <int>{state.cycleLength},
                onSelectionChanged: (values) {
                  state.setCycleLength(values.first);
                },
              ),
              const SizedBox(height: 32),
              Text(
                '通知設定',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _NotificationTile(
                title: '前日通知',
                enabled: state.notifyDayBefore,
                timeLabel: formatter.format(
                  DateTime(0, 1, 1, state.notifyDayBeforeTime.hour, state.notifyDayBeforeTime.minute),
                ),
                onToggle: (value) {
                  state.setNotifyDayBefore(value);
                },
                onPickTime: () async {
                  final selected = await _pickTime(context, state.notifyDayBeforeTime);
                  if (selected != null) {
                    state.setNotifyDayBeforeTime(selected);
                  }
                },
              ),
              _NotificationTile(
                title: '当日通知',
                enabled: state.notifyDayOf,
                timeLabel: formatter.format(
                  DateTime(0, 1, 1, state.notifyDayOfTime.hour, state.notifyDayOfTime.minute),
                ),
                onToggle: (value) {
                  state.setNotifyDayOf(value);
                },
                onPickTime: () async {
                  final selected = await _pickTime(context, state.notifyDayOfTime);
                  if (selected != null) {
                    state.setNotifyDayOfTime(selected);
                  }
                },
              ),
              SwitchListTile.adaptive(
                title: const Text('自動スケジュール更新'),
                value: state.autoSchedule,
                onChanged: (value) {
                  state.setAutoSchedule(value);
                },
              ),
              const SizedBox(height: 24),
              Text(
                'テーマカラー',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  for (var i = 0; i < state.availableThemeColors.length; i++)
                    GestureDetector(
                      onTap: () => state.setThemeColorIndex(i),
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: state.availableThemeColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == state.themeColorIndex
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: i == state.themeColorIndex
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                '在庫',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              SwitchListTile.adaptive(
                title: const Text('在庫数を表示'),
                value: state.showInventory,
                onChanged: (value) {
                  state.setShowInventory(value);
                },
              ),
              if (state.showInventory) ...[
                _NumberField(
                  label: '現在の在庫',
                  initialValue: state.inventoryCount,
                  onChanged: (value) {
                    state.setInventoryCount(value);
                  },
                ),
                _NumberField(
                  label: 'N個以下で通知',
                  initialValue: state.inventoryThreshold,
                  onChanged: (value) {
                    state.setInventoryThreshold(value);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay current) async {
    final isCupertino = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    if (isCupertino) {
      TimeOfDay? selected;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) {
          return Container(
            height: 260,
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(
                      0,
                      1,
                      1,
                      current.hour,
                      current.minute,
                    ),
                    onDateTimeChanged: (value) {
                      selected = TimeOfDay.fromDateTime(value);
                    },
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('完了'),
                ),
              ],
            ),
          );
        },
      );
      return selected ?? current;
    }

    return showTimePicker(
      context: context,
      initialTime: current,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.enabled,
    required this.timeLabel,
    required this.onToggle,
    required this.onPickTime,
  });

  final String title;
  final bool enabled;
  final String timeLabel;
  final ValueChanged<bool> onToggle;
  final Future<void> Function() onPickTime;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text('通知時刻: $timeLabel'),
      trailing: Switch.adaptive(
        value: enabled,
        onChanged: onToggle,
      ),
      onTap: enabled
          ? () {
              onPickTime();
            }
          : null,
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue.toString()) {
      _controller.text = widget.initialValue.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null) {
            widget.onChanged(parsed);
          }
        },
      ),
    );
  }
}
