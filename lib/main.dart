import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_service.dart';
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
          home: const RootScreen(),
        );
      },
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactLensState>(
      builder: (context, state, _) {
        if (!state.isInitialOnboardingCompleted) {
          return const InitialOnboardingScreen();
        }
        return const HomeScreen();
      },
    );
  }
}

class InitialOnboardingScreen extends StatefulWidget {
  const InitialOnboardingScreen({super.key});

  @override
  State<InitialOnboardingScreen> createState() =>
      _InitialOnboardingScreenState();
}

class _InitialOnboardingScreenState extends State<InitialOnboardingScreen> {
  LensUsageType? _selectedUsageType;
  DateTime? _selectedStartDate;
  bool _isProcessing = false;

  bool get _needsStartDate =>
      _selectedUsageType == LensUsageType.twoWeek ||
      _selectedUsageType == LensUsageType.oneMonth;

  void _selectUsageType(LensUsageType type) {
    setState(() {
      _selectedUsageType = type;
      if (!_needsStartDate) {
        _selectedStartDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactLensState>();
    final accentColor = state.themeColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accentColor,
        title: const Text('初期設定'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '普段使っているコンタクトレンズの種類を教えてください',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SelectionChip(
                    label: '2week',
                    isSelected: _selectedUsageType == LensUsageType.twoWeek,
                    color: accentColor,
                    onTap: () => _selectUsageType(LensUsageType.twoWeek),
                  ),
                  _SelectionChip(
                    label: '1day',
                    isSelected: _selectedUsageType == LensUsageType.oneDay,
                    color: accentColor,
                    onTap: () => _selectUsageType(LensUsageType.oneDay),
                  ),
                  _SelectionChip(
                    label: '1month',
                    isSelected: _selectedUsageType == LensUsageType.oneMonth,
                    color: accentColor,
                    onTap: () => _selectUsageType(LensUsageType.oneMonth),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_needsStartDate) ...[
                Text(
                  '現在コンタクトを使用中の場合は、使用開始日を選択してください',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: Icon(Icons.calendar_today, color: accentColor),
                  title: Text(
                    _selectedStartDate == null
                        ? '未選択'
                        : formatJapaneseDateWithWeekday(_selectedStartDate!),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  onTap: _pickStartDate,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Builder(
                  builder: (context) {
                    final canProceed =
                        !_isProcessing && _selectedUsageType != null;
                    return ElevatedButton(
                      onPressed: canProceed ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '次へ進む',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _selectedUsageType = LensUsageType.skip;
                          });
                          _save();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueGrey,
                  ),
                  child: const Text('スキップ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initialDate = _selectedStartDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365 * 10)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: '使用開始日',
    );

    if (picked != null) {
      setState(() => _selectedStartDate = picked);
    }
  }

  Future<void> _save() async {
    if (_isProcessing) return;
    if (_selectedUsageType == null) return;
    setState(() => _isProcessing = true);

    final state = context.read<ContactLensState>();

    switch (_selectedUsageType!) {
      case LensUsageType.twoWeek:
        await state.setCycleLength(ContactLensState.twoWeekCycle);
        if (_selectedStartDate != null) {
          await state.recordExchangeOn(_selectedStartDate!);
        } else {
          await state.markUsageNotStarted();
        }
        break;
      case LensUsageType.oneMonth:
        await state.setCycleLength(ContactLensState.oneMonthCycle);
        if (_selectedStartDate != null) {
          await state.recordExchangeOn(_selectedStartDate!);
        } else {
          await state.markUsageNotStarted();
        }
        break;
      case LensUsageType.oneDay:
        await state.setCycleLength(ContactLensState.oneDayCycle);
        await state.recordExchangeOn(DateTime.now());
        break;
      case LensUsageType.skip:
        await state.markUsageNotStarted();
        break;
    }

    await state.dismissInitialOnboarding();

    if (mounted && _selectedUsageType == LensUsageType.oneDay) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const InventoryOnboardingScreen()),
      );
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }
}

enum LensUsageType { twoWeek, oneDay, oneMonth, skip }

class InventoryOnboardingScreen extends StatefulWidget {
  const InventoryOnboardingScreen({super.key});

  @override
  State<InventoryOnboardingScreen> createState() =>
      _InventoryOnboardingScreenState();
}

class _InventoryOnboardingScreenState
    extends State<InventoryOnboardingScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactLensState>();
    final accentColor = state.themeColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accentColor,
        title: const Text('初期設定'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '在庫設定をはじめましょう',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'コンタクトレンズの残り個数を登録すると、\nホーム画面で在庫を確認でき、\n少なくなったときには通知でお知らせします。\n\n後から設定で変更することもできます。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 24),
              InventoryOnboardingCard(
                accentColor: accentColor,
                onSetup: _startInventorySetup,
                onDismiss: _skipOnboarding,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startInventorySetup() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final state = context.read<ContactLensState>();
    await _completeOnboarding(state, enableInventory: false);
    final saved = await showInventoryPicker(
      context,
      state,
      isCurrentInventory: true,
    );

    if (saved) {
      await _completeOnboarding(state, enableInventory: true);
      _closeOnboarding();
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _skipOnboarding() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final state = context.read<ContactLensState>();
    await _completeOnboarding(state, enableInventory: false);
    _closeOnboarding(result: false);

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _completeOnboarding(
    ContactLensState state, {
    required bool enableInventory,
  }) async {
    await state.dismissInventoryOnboarding();

    if (enableInventory) {
      await state.setShowInventory(true);
    }
  }

  void _closeOnboarding({bool result = true}) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
    }
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
    required this.hasStarted,
  });

  factory ContactProfile.primaryDefaults() => ContactProfile(
        name: 'コンタクト1',
        lensType: 'コンタクト',
        cycleLength: 14,
        startDate: null,
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
        hasStarted: false,
      );

  factory ContactProfile.secondaryPlaceholder() => ContactProfile(
        name: 'コンタクト2',
        lensType: 'コンタクト',
        cycleLength: 14,
        startDate: null,
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
        hasStarted: false,
      );

  final String name;
  final String lensType;
  final int cycleLength;
  final DateTime? startDate;
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
  final bool hasStarted;

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
    bool? hasStarted,
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
      hasStarted: hasStarted ?? this.hasStarted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lensType': lensType,
      'cycleLength': cycleLength,
      'startDate': startDate?.millisecondsSinceEpoch,
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
      'hasStarted': hasStarted,
    };
  }

  factory ContactProfile.fromMap(Map<String, dynamic> map) {
    final notifyBeforeMinutes = map['notifyDayBeforeTime'] as int?;
    final notifyOfMinutes = map['notifyDayOfTime'] as int?;
    final inventoryAlertMinutes = map['inventoryAlertTime'] as int?;

    final startDateMillis = map['startDate'] as int?;
    final normalizedStartDate = startDateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startDateMillis)
        : null;

    return ContactProfile(
      name: map['name'] as String? ?? 'コンタクト1',
      lensType: map['lensType'] as String? ?? 'コンタクト',
      cycleLength: map['cycleLength'] as int? ?? 14,
      startDate: normalizedStartDate != null
          ? DateTime(
              normalizedStartDate.year,
              normalizedStartDate.month,
              normalizedStartDate.day,
            )
          : null,
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
      hasStarted: map['hasStarted'] as bool? ?? true,
    );
  }

  ContactProfile autoAdvanced(DateTime today) {
    if (!autoSchedule || startDate == null || !hasStarted) {
      return this;
    }

    final normalizedToday = _dateOnly(today);
    var start = _dateOnly(startDate!);
    var nextExchange = start.add(Duration(days: cycleLength));

    while (!normalizedToday.isBefore(nextExchange)) {
      start = nextExchange;
      nextExchange = start.add(Duration(days: cycleLength));
    }

    if (start != _dateOnly(startDate!)) {
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

class BackgroundOption {
  const BackgroundOption({
    required this.id,
    required this.label,
    this.assetPath,
    this.themeColorIndex,
  });

  final String id;
  final String label;
  final String? assetPath;
  final int? themeColorIndex;

  bool get isNone => assetPath == null;
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
  static const _initialOnboardingDismissedKey = 'initialOnboardingDismissed';
  static const _soundEnabledKey = 'soundEnabled';
  static const _showSecondProfileKey = 'showSecondProfile';
  static const _isPremiumKey = 'isPremium';
  static const _savedAppVersionKey = 'savedAppVersion';
  static const _postUpdateExchangeCountKey = 'postUpdateExchangeCount';
  static const _hasRequestedReviewKey = 'hasRequestedReview';
  static const _backgroundSelectionKey = 'selectedBackgroundId';
  static const _backgroundNoneId = 'none';
  static const premiumMonthlyProductId = 'premium_monthly_300';
  static const premiumYearlyProductId = 'premium_yearly_2500';
  static const Set<String> premiumProductIds = {
    premiumMonthlyProductId,
    premiumYearlyProductId,
  };

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

  static const List<BackgroundOption> _availableBackgrounds = [
    BackgroundOption(
      id: _backgroundNoneId,
      label: '背景なし',
    ),
    BackgroundOption(
      id: 'bear_autumn',
      label: 'クマのイラスト',
      assetPath: 'assets/backgrounds/bear_autumn.png',
      themeColorIndex: 2,
    ),
  ];

  SharedPreferences? _prefs;

  final List<ContactProfile> _profiles = [
    ContactProfile.primaryDefaults(),
    ContactProfile.secondaryPlaceholder(),
  ];
  int _selectedProfileIndex = 0;
  bool _inventoryOnboardingDismissed = false;
  bool _initialOnboardingDismissed = false;
  bool _showSecondProfile = true;
  bool _isPremium = false;
  String? _savedAppVersion;
  int _postUpdateExchangeCount = 0;
  bool _hasRequestedReview = false;
  List<ProductDetails> _availableProducts = [];
  String? _productLoadError;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _midnightRefreshTimer;
  DateTime? _lastEvaluatedDate;
  String? _selectedBackgroundId;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _isPremium = _prefs?.getBool(_isPremiumKey) ?? false;
    _savedAppVersion = _prefs?.getString(_savedAppVersionKey);
    _postUpdateExchangeCount =
        _prefs?.getInt(_postUpdateExchangeCountKey) ?? 0;
    _hasRequestedReview = _prefs?.getBool(_hasRequestedReviewKey) ?? false;
    await _syncAppVersionState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _purchaseSubscription?.cancel(),
    );
    _selectedProfileIndex = _prefs?.getInt(_selectedProfileIndexKey) ?? 0;
    _inventoryOnboardingDismissed =
        _prefs?.getBool(_inventoryOnboardingDismissedKey) ?? false;
    _initialOnboardingDismissed =
        _prefs?.getBool(_initialOnboardingDismissedKey) ?? false;
    _showSecondProfile = _prefs?.getBool(_showSecondProfileKey) ?? true;
    _selectedBackgroundId =
        _normalizeBackgroundId(_prefs?.getString(_backgroundSelectionKey));

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
    await queryProducts();
    await _applyPremiumRestrictions();
    await _persist();
    await _rescheduleNotifications();
    unawaited(_restorePurchases());
    // 日付変更の再評価を行うため、初回ロード時に今日の日付を記録して0:00更新を設定する。
    _lastEvaluatedDate = _today();
    _scheduleMidnightRefresh();
    notifyListeners();
  }

  ContactProfile get _profile => _profiles[_selectedProfileIndex];
  int get selectedProfileIndex => _selectedProfileIndex;
  bool get hasSecondProfile => _profiles[1].isRegistered;
  bool get showSecondProfile => _showSecondProfile;
  bool get isPremium => _isPremium;
  List<ProductDetails> get availableProducts => List.unmodifiable(_availableProducts);
  String? get productLoadError => _productLoadError;
  List<BackgroundOption> get availableBackgroundOptions =>
      List.unmodifiable(_availableBackgrounds);
  String get currentProfileName => _profile.name;
  String get currentLensType => _profile.lensType;
  String profileName(int index) => _profiles[index].name;
  String profileLensType(int index) => _profiles[index].lensType;

  int get cycleLength => _profile.cycleLength;
  bool get hasStarted => _profile.startDate != null && _profile.hasStarted;
  DateTime? get startDate => hasStarted ? _profile.startDate : null;
  DateTime get today => _today();
  DateTime? get exchangeDate {
    if (startDate == null) {
      return null;
    }
    final normalizedStart = _dateOnly(startDate!);
    return normalizedStart.add(Duration(days: _profile.cycleLength));
  }
  DateTime? get expiryDay {
    if (exchangeDate == null) {
      return null;
    }
    return _dateOnly(exchangeDate!);
  }
  bool get isExpired {
    final expiry = expiryDay;
    if (expiry == null) {
      return false;
    }
    return _today().isAfter(expiry);
  }
  bool get autoSchedule => _profile.autoSchedule;
  bool get notifyDayBefore => _profile.notifyDayBefore;
  TimeOfDay get notifyDayBeforeTime => _profile.notifyDayBeforeTime;
  bool get notifyDayOf => _profile.notifyDayOf;
  TimeOfDay get notifyDayOfTime => _profile.notifyDayOfTime;
  int get _resolvedThemeColorIndex =>
      selectedBackgroundOption?.themeColorIndex ?? _profile.themeColorIndex;
  Color get themeColor => _colorWithDefaultOpacity(_resolvedThemeColorIndex);
  int get themeColorIndex => _resolvedThemeColorIndex;
  String? get selectedBackgroundId => _selectedBackgroundId;
  BackgroundOption? get selectedBackgroundOption =>
      _backgroundOptionForId(_selectedBackgroundId);
  String? get selectedBackgroundAsset =>
      selectedBackgroundOption?.assetPath;
  bool get notifyInventoryAlert => _profile.inventoryAlertEnabled;
  TimeOfDay get inventoryAlertTime => _profile.inventoryAlertTime;
  bool get showInventory => _profile.showInventory;
  int? get inventoryCount => _profile.inventoryCount;
  int get inventoryThreshold => _profile.inventoryThreshold;
  bool get inventoryOnboardingDismissed => _inventoryOnboardingDismissed;
  bool get shouldShowInitialOnboarding => !_initialOnboardingDismissed;
  bool get isInitialOnboardingCompleted => !shouldShowInitialOnboarding;
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
    final expiry = expiryDay;
    if (expiry == null) {
      return 0;
    }
    final today = _today();
    final diff = expiry.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }

  int get overdueDays {
    final expiry = expiryDay;
    if (expiry == null) {
      return 0;
    }
    final today = _today();
    if (!today.isAfter(expiry)) {
      return 0;
    }
    return today.difference(expiry).inDays;
  }

  double get progress {
    if (startDate == null) {
      return 0;
    }
    final total = _profile.cycleLength;
    if (total == 0) {
      return 0;
    }
    final today = _today();
    final elapsed = today.difference(_dateOnly(startDate!)).inDays;
    final clamped = elapsed.clamp(0, total).toDouble();
    return clamped / total;
  }

  bool get shouldShowInventoryAlert => _profile.showInventory &&
      _profile.inventoryCount != null &&
      _profile.inventoryCount! <= _profile.inventoryThreshold;

  bool get shouldShowInventoryOnboarding => !_inventoryOnboardingDismissed;

  bool get isInventoryOnboardingCompleted => !shouldShowInventoryOnboarding;

  Future<void> dismissInitialOnboarding() async {
    if (_initialOnboardingDismissed) return;
    _initialOnboardingDismissed = true;
    await _prefs?.setBool(_initialOnboardingDismissedKey, true);
    notifyListeners();
  }

  Future<void> recordExchangeToday() async {
    await _updateProfile(
      (current) => current.copyWith(
        startDate: _today(),
        hasStarted: true,
      ),
    );
    await _handlePostUpdateExchangeReview();
  }

  Future<void> recordExchangeOn(DateTime start) async {
    await _updateProfile(
      (current) => current.copyWith(
        startDate: DateTime(start.year, start.month, start.day),
        hasStarted: true,
      ),
    );
    await _handlePostUpdateExchangeReview();
  }

  Future<void> markUsageNotStarted() async {
    await _updateProfile(
      (current) => current.copyWith(
        startDate: null,
        hasStarted: false,
      ),
    );
  }

  Future<void> setCycleLength(int days) async {
    await _updateProfile((current) {
      final shouldUpdateInventoryThreshold =
          days == oneDayCycle && current.inventoryThreshold == 2;
      return current.copyWith(
        cycleLength: days,
        inventoryThreshold:
            shouldUpdateInventoryThreshold ? 8 : current.inventoryThreshold,
      );
    });
  }

  Future<void> shiftStartDateByDays(int days) async {
    if (startDate == null) {
      await recordExchangeToday();
      return;
    }
    final current = _dateOnly(startDate!);
    await _updateProfile(
      (profile) => profile.copyWith(
        startDate: current.add(Duration(days: days)),
        hasStarted: true,
      ),
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

  Future<void> setSelectedBackground(String? id) async {
    final normalized = _normalizeBackgroundId(id);
    if (_selectedBackgroundId == normalized) return;
    _selectedBackgroundId = normalized;
    await _prefs?.setString(
      _backgroundSelectionKey,
      _selectedBackgroundId ?? _backgroundNoneId,
    );
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
    required String primaryLensType,
    required String secondaryName,
    required String secondaryLensType,
  }) async {
    final trimmedPrimary = primaryName.trim();
    final trimmedSecondary = secondaryName.trim();
    final trimmedPrimaryLens = primaryLensType.trim();
    final trimmedSecondaryLens = secondaryLensType.trim();

    if (trimmedSecondary.isEmpty || trimmedSecondaryLens.isEmpty) return;
    final secondaryDefaults = ContactProfile.secondaryPlaceholder();
    _profiles[0] = _profiles[0].copyWith(
      name: trimmedPrimary.isEmpty ? _profiles[0].name : trimmedPrimary,
      lensType:
          trimmedPrimaryLens.isEmpty ? _profiles[0].lensType : trimmedPrimaryLens,
    );
    _profiles[1] = secondaryDefaults.copyWith(
      name: trimmedSecondary,
      lensType: trimmedSecondaryLens.isEmpty
          ? secondaryDefaults.lensType
          : trimmedSecondaryLens,
      themeColorIndex: _secondProfileDefaultColorIndex,
      isRegistered: true,
    );
    _profiles[1] = _profiles[1].autoAdvanced(_today());
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> purchasePremium(ProductDetails product) async {
    if (!await _inAppPurchase.isAvailable()) {
      return;
    }
    final param = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: param);
  }

  Future<void> queryProducts() async {
    _productLoadError = null;
    try {
      if (!await _inAppPurchase.isAvailable()) {
        _availableProducts = [];
        _productLoadError =
            '現在購入情報を取得できません（ストア設定前/テスト環境未設定の可能性があります）';
        notifyListeners();
        return;
      }

      final response = await _inAppPurchase.queryProductDetails(premiumProductIds);
      _availableProducts = response.productDetails;

      if (response.error != null || _availableProducts.isEmpty) {
        _productLoadError =
            '現在購入情報を取得できません（ストア設定前/テスト環境未設定の可能性があります）';
      }
    } catch (e) {
      debugPrint('Failed to load product details: $e');
      _availableProducts = [];
      _productLoadError =
          '現在購入情報を取得できません（ストア設定前/テスト環境未設定の可能性があります）';
    }

    notifyListeners();
  }

  Future<void> restorePurchases() async {
    if (!await _inAppPurchase.isAvailable()) {
      return;
    }
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _restorePurchases() async {
    await restorePurchases();
  }

  ProductDetails? productForId(String productId) {
    try {
      return _availableProducts.firstWhere((product) => product.id == productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> setPremium(bool value) => _setPremium(value);

  Future<void> _setPremium(bool value) async {
    if (_isPremium == value) return;
    _isPremium = value;
    await _prefs?.setBool(_isPremiumKey, _isPremium);
    notifyListeners();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> detailsList) {
    for (final purchase in detailsList) {
      if (premiumProductIds.contains(purchase.productID) &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        unawaited(setPremium(true));
        // 購入完了後など、ユーザーが価値を感じたタイミングでレビュー表示を検討する例。
        // ReviewService().requestReview();
      }
      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
    }
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
    final rawStartDate = startMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startMillis)
        : DateTime.now();
    final startDate =
        DateTime(rawStartDate.year, rawStartDate.month, rawStartDate.day);

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
      hasStarted: true,
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

  Future<void> _syncAppVersionState() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    if (_savedAppVersion == currentVersion) {
      return;
    }
    _savedAppVersion = currentVersion;
    _postUpdateExchangeCount = 0;
    _hasRequestedReview = false;
    await _prefs?.setString(_savedAppVersionKey, currentVersion);
    await _prefs?.setInt(
      _postUpdateExchangeCountKey,
      _postUpdateExchangeCount,
    );
    await _prefs?.setBool(_hasRequestedReviewKey, _hasRequestedReview);
  }

  Future<void> _handlePostUpdateExchangeReview() async {
    _postUpdateExchangeCount += 1;
    await _prefs?.setInt(
      _postUpdateExchangeCountKey,
      _postUpdateExchangeCount,
    );
    if (_postUpdateExchangeCount < 2 || _hasRequestedReview) {
      return;
    }
    await ReviewService().requestReview();
    _hasRequestedReview = true;
    await _prefs?.setBool(_hasRequestedReviewKey, _hasRequestedReview);
  }

  Future<void> _applyPremiumRestrictions() async {
    if (_isPremium) return;
    var updated = false;
    for (var i = 0; i < _profiles.length; i++) {
      if (_profiles[i].autoSchedule) {
        _profiles[i] = _profiles[i].copyWith(autoSchedule: false);
        updated = true;
      }
    }
    if (updated) {
      await _persist();
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
    await _prefs?.setBool(
      _initialOnboardingDismissedKey,
      _initialOnboardingDismissed,
    );
    await _prefs?.setBool(_showSecondProfileKey, _showSecondProfile);
    await _prefs?.setBool(_isPremiumKey, _isPremium);
    await _prefs?.setString(
      _backgroundSelectionKey,
      _selectedBackgroundId ?? _backgroundNoneId,
    );
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _scheduleMidnightRefresh() {
    _midnightRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    final duration = nextMidnight.difference(now);
    _midnightRefreshTimer = Timer(duration, () {
      // 0:00になったら日付の再評価を行い、リスナーへ更新通知する。
      unawaited(_handleMidnightRefresh());
    });
  }

  Future<void> _handleMidnightRefresh() async {
    final today = _today();
    if (_lastEvaluatedDate != null && _dateOnly(_lastEvaluatedDate!) == today) {
      _scheduleMidnightRefresh();
      return;
    }
    // 日付が変わった場合のみ評価し直し、通知/スケジュールを更新する。
    _lastEvaluatedDate = today;
    _autoAdvanceAll();
    await _persist();
    await _rescheduleNotifications();
    notifyListeners();
    _scheduleMidnightRefresh();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _rescheduleNotifications() async {
    await _notificationsPlugin.cancel(_dayBeforeNotificationId);
    await _notificationsPlugin.cancel(_dayOfNotificationId);
    await _notificationsPlugin.cancel(_inventoryAlertNotificationId);

    if (exchangeDate == null) {
      return;
    }

    final exchange = exchangeDate!;
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
          '交換まであと3日です。準備をしておきましょう',
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

    final contactLabel = _profiles[1].isRegistered ? _profile.name : 'コンタクト';

    if (_profile.notifyDayBefore) {
      final scheduled = _scheduledDateTime(
        exchange.subtract(const Duration(days: 1)),
        _profile.notifyDayBeforeTime,
      );
      if (scheduled.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          _dayBeforeNotificationId,
          '$contactLabel交換の予定があります',
          '明日は$contactLabelの交換日です。忘れずにご準備ください。',
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
          '今日は${contactLabel}交換日です',
          '新しい$contactLabelに交換しましょう。',
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

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _midnightRefreshTimer?.cancel();
    super.dispose();
  }

  Color _colorWithDefaultOpacity(int index) {
    final baseColor = _availableThemeColors[index];
    if (index == 0) {
      return baseColor.withOpacity(0.9);
    }
    return baseColor;
  }

  String? _normalizeBackgroundId(String? id) {
    if (id == null || id.isEmpty || id == _backgroundNoneId) {
      return null;
    }
    final option = _backgroundOptionForId(id);
    if (option == null || option.assetPath == null) {
      return null;
    }
    return id;
  }

  BackgroundOption? _backgroundOptionForId(String? id) {
    if (id == null) {
      return null;
    }
    for (final option in _availableBackgrounds) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AudioPlayer _audioPlayer;
  DateTime? _lastEvaluatedDate;
  double _progressTweenBegin = 0;
  double _progressTweenEnd = 0;

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

  double _progressForDate(ContactLensState state, DateTime date) {
    final startDate = state.startDate;
    if (startDate == null) {
      return 0;
    }
    final total = state.cycleLength;
    if (total == 0) {
      return 0;
    }
    final startDateOnly = DateUtils.dateOnly(startDate);
    final dateOnly = DateUtils.dateOnly(date);
    final elapsed = dateOnly.difference(startDateOnly).inDays;
    final clamped = elapsed.clamp(0, total).toDouble();
    return clamped / total;
  }

  void _syncProgressAnimation(ContactLensState state) {
    final today = DateUtils.dateOnly(DateTime.now());
    final currentProgress = state.progress;
    if (_lastEvaluatedDate == null) {
      _lastEvaluatedDate = today;
      _progressTweenBegin = currentProgress;
      _progressTweenEnd = currentProgress;
      return;
    }
    if (!DateUtils.isSameDay(_lastEvaluatedDate, today)) {
      final previousDate = today.subtract(const Duration(days: 1));
      final previousProgress = _progressForDate(state, previousDate);
      _lastEvaluatedDate = today;
      _progressTweenBegin = previousProgress;
      _progressTweenEnd = previousProgress;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _progressTweenBegin = previousProgress;
          _progressTweenEnd = currentProgress;
        });
      });
      return;
    }
    _progressTweenBegin = currentProgress;
    _progressTweenEnd = currentProgress;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactLensState>();
    _syncProgressAnimation(state);
    final themeColor = state.themeColor;
    final backgroundAsset = state.selectedBackgroundAsset;
    final startDate = state.startDate;
    final today = state.today;
    final exchangeDate = state.exchangeDate;
    final isUnconfigured = startDate == null;
    final isScheduled = startDate != null && startDate.isAfter(today);
    final isActive = startDate != null && !startDate.isAfter(today);
    final shouldShowUsageNotStarted = isUnconfigured || isScheduled;
    final daysRemaining = isActive ? state.remainingDays : 0;
    final daysOverdue = isActive ? state.overdueDays : 0;
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final exchangeDateDateOnly = exchangeDate == null
        ? null
        : DateTime(exchangeDate.year, exchangeDate.month, exchangeDate.day);
    // 期限切れは当日ではなく翌日から。
    final isExpired = isActive &&
        exchangeDateDateOnly != null &&
        todayDateOnly.isAfter(exchangeDateDateOnly);
    final isOverdue = isExpired;
    // 期限切れUIは期限切れ判定が true のときのみ表示する。
    final shouldShowEmptyState = shouldShowUsageNotStarted || isExpired;
    final Color mainColor = isOverdue ? overdueColor : themeColor;
    final Color fadedColor = mainColor.withOpacity(0.2);
    final cycleLabel = state.cycleLabel;
    final shouldShowExpiredWarning = isActive && isOverdue;
    final scheduledStartDateLabel = startDate == null
        ? ''
        : '${startDate.month}月${startDate.day.toString().padLeft(2, '0')}日';
    final chartSize = math.min(MediaQuery.of(context).size.width * 0.8, 320.0);
    final hasSecondProfile = state.hasSecondProfile;
    final showSecondProfile = state.showSecondProfile;
    final secondVisible = hasSecondProfile && showSecondProfile;
    final canShowSecondProfile = secondVisible;
    final shouldShowInventoryAlert = state.shouldShowInventoryAlert;
    final inventoryCount = state.inventoryCount;
    final shouldShiftMainContent = secondVisible && shouldShowInventoryAlert;
    final mainContentOffset =
        shouldShiftMainContent ? const Offset(0, -24) : Offset.zero;
    final hasBackground = backgroundAsset != null;

    return Scaffold(
      appBar: hasBackground
          ? null
          : AppBar(
              title: const Text('コンタクト交換管理'),
              backgroundColor: themeColor,
              elevation: 0,
            ),
      body: Stack(
        children: [
          if (hasBackground) ...[
            Positioned.fill(
              child: Image.asset(
                backgroundAsset!,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
          SafeArea(
            top: false,
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final adjustedChartSize = () {
                      final heightAllowance = constraints.maxHeight - 240;
                      if (heightAllowance <= 0) {
                        return chartSize;
                      }
                      return math.min(
                        chartSize,
                        math.max(200.0, heightAllowance),
                      );
                    }();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasBackground)
                            SizedBox(
                              height: MediaQuery.of(context).padding.top +
                                  kToolbarHeight,
                            ),
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
                                      onSelected: (index) =>
                                          state.switchProfile(index),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (canShowSecondProfile) const SizedBox(height: 20),
                          Expanded(
                            child: Center(
                              child: Transform.translate(
                                offset: mainContentOffset,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: adjustedChartSize,
                                      height: adjustedChartSize + 68,
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
                                                  padding:
                                                      const EdgeInsets.only(top: 12),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
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
                                              width: adjustedChartSize,
                                              height: adjustedChartSize,
                                              child: isActive && !isExpired
                                                  ? TweenAnimationBuilder<double>(
                                                      tween: Tween<double>(
                                                        begin: _progressTweenBegin,
                                                        end: _progressTweenEnd,
                                                      ),
                                                      duration:
                                                          _progressTweenBegin == _progressTweenEnd
                                                              ? Duration.zero
                                                              : const Duration(
                                                                  milliseconds: 400,
                                                                ),
                                                      curve: Curves.easeInOut,
                                                      builder: (context, animatedProgress, _) {
                                                        return CustomPaint(
                                                          size: Size(
                                                            adjustedChartSize,
                                                            adjustedChartSize,
                                                          ),
                                                          painter:
                                                              CircularProgressPainter(
                                                            progress: animatedProgress,
                                                            color: mainColor,
                                                            backgroundColor: fadedColor,
                                                            isOverdue: isOverdue,
                                                          ),
                                                          child: Center(
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment.center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment.center,
                                                              children: [
                                                                if (shouldShowExpiredWarning)
                                                                  Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment.center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment.center,
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
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          maxLines: 2,
                                                                          overflow:
                                                                              TextOverflow.visible,
                                                                          style: TextStyle(
                                                                            fontSize: 20,
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: overdueColor,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  )
                                                                else
                                                                  Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment.center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment.end,
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
                                                                          fontWeight:
                                                                              FontWeight.bold,
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
                                                                if (isActive &&
                                                                    exchangeDate != null &&
                                                                    !shouldShowExpiredWarning)
                                                                  Text(
                                                                    '${formatJapaneseDateWithWeekday(startDate!)} ～ ${formatJapaneseDateWithWeekday(exchangeDate!)}',
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
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (shouldShowEmptyState) ...[
                                      const SizedBox(height: 24),
                                      Text(
                                        isExpired
                                            ? 'レンズの使用期限を過ぎています\n'
                                                '新しいレンズに交換しましょう！'
                                            : isUnconfigured
                                                ? 'レンズ管理を始めましょう！\n'
                                                    '下の「レンズを交換する」ボタンから\n'
                                                    '最初の交換を記録できます'
                                                : 'レンズ使用開始予定です！\n'
                                                    '$scheduledStartDateLabelから管理が始まります',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: themeColor,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ] else
                                      const SizedBox(height: 32),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _onExchangeButtonPressed(state),
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
                                    if (shouldShowInventoryAlert) ...[
                                      const SizedBox(height: 24),
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
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                ),
                if (shouldShowEmptyState)
                  IgnorePointer(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -32),
                        child: Image.asset(
                          'assets/icons/app_icon_empty_state.png',
                          width: 180,
                          height: 180,
                        ),
                      ),
                    ),
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
                        onPressed: () async {
                          if (state.soundEnabled) {
                            await _audioPlayer.play(
                              AssetSource('sounds/決定ボタンを押す50.mp3'),
                            );
                          }
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
        ],
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

  Future<void> _onExchangeButtonPressed(ContactLensState state) async {
    if (state.showInventory && (state.inventoryCount == null || state.inventoryCount! <= 0)) {
      final shouldExchange = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('在庫がありません'),
          content: const Text('在庫を減らさずに交換を記録しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('交換する'),
            ),
          ],
        ),
      );

      if (shouldExchange != true || !mounted) {
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

  static const _cycleRanges = <String, _CycleRange>{
    '1day': _CycleRange(min: 1, max: 2, defaultValue: 1),
    '2week': _CycleRange(min: 10, max: 18, defaultValue: 14),
    '1month': _CycleRange(min: 28, max: 31, defaultValue: 30),
  };

  String _resolveCyclePeriod(int cycleLength) {
    if (cycleLength >= _cycleRanges['1day']!.min &&
        cycleLength <= _cycleRanges['1day']!.max) {
      return '1day';
    }
    if (cycleLength >= _cycleRanges['1month']!.min &&
        cycleLength <= _cycleRanges['1month']!.max) {
      return '1month';
    }
    return '2week';
  }

  _CycleRange _rangeForPeriod(String period) {
    return _cycleRanges[period] ?? _cycleRanges['2week']!;
  }

  @override
  Widget build(BuildContext context) {
    // 例: 設定画面のボタンから手動でレビュー導線を用意する場合
    // ReviewService().openStorePage(appStoreId: '123456789');
    return Consumer<ContactLensState>(
      builder: (context, state, _) {
        final cyclePeriod = _resolveCyclePeriod(state.cycleLength);
        final cycleRange = _rangeForPeriod(cyclePeriod);
        final canDecreaseCycle = state.cycleLength > cycleRange.min;
        final canIncreaseCycle = state.cycleLength < cycleRange.max;
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
                    state.setCycleLength(_cycleRanges['2week']!.defaultValue);
                  } else if (value == '1month') {
                    state.setCycleLength(_cycleRanges['1month']!.defaultValue);
                  } else if (value == '1day') {
                    state.setCycleLength(_cycleRanges['1day']!.defaultValue);
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
                    state.setCycleLength(_cycleRanges['2week']!.defaultValue);
                  } else if (value == '1month') {
                    state.setCycleLength(_cycleRanges['1month']!.defaultValue);
                  } else if (value == '1day') {
                    state.setCycleLength(_cycleRanges['1day']!.defaultValue);
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
                    state.setCycleLength(_cycleRanges['2week']!.defaultValue);
                  } else if (value == '1month') {
                    state.setCycleLength(_cycleRanges['1month']!.defaultValue);
                  } else if (value == '1day') {
                    state.setCycleLength(_cycleRanges['1day']!.defaultValue);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '期限（日数）',
                          style: TextStyle(fontSize: 16),
                        ),
                        Row(
                          children: [
                            _CycleAdjustButton(
                              icon: Icons.remove,
                              isEnabled: canDecreaseCycle,
                              onTap: canDecreaseCycle
                                  ? () => state.setCycleLength(
                                        (state.cycleLength - 1)
                                            .clamp(cycleRange.min, cycleRange.max)
                                            .toInt(),
                                      )
                                  : null,
                              color: themeColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${state.cycleLength}日',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _CycleAdjustButton(
                              icon: Icons.add,
                              isEnabled: canIncreaseCycle,
                              onTap: canIncreaseCycle
                                  ? () => state.setCycleLength(
                                        (state.cycleLength + 1)
                                            .clamp(cycleRange.min, cycleRange.max)
                                            .toInt(),
                                      )
                                  : null,
                              color: themeColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
                subtitle: '交換前に、在庫が少なくなったら通知',
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
              _buildSectionHeader('コンタクトの在庫管理'),
              if (state.shouldShowInventoryOnboarding) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InventoryOnboardingCard(
                    onSetup: () =>
                        _startInventoryOnboarding(context: context, state: state),
                    onDismiss: () => _dismissInventoryOnboarding(state),
                    accentColor: themeColor,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!state.shouldShowInventoryOnboarding) ...[
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
                    title: const Text('在庫アラート基準'),
                    subtitle: Text('${state.inventoryThreshold} 個以下でお知らせ'),
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
              ],
              const Divider(height: 32),
              if (!state.isPremium) ...[
                _buildSectionHeader('Premium'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListTile(
                    leading:
                        Icon(Icons.workspace_premium_outlined, color: themeColor),
                    title: const Text('Premiumを試す'),
                    subtitle: const Text(
                      'プレミアム機能を2週間無料でお試しできます。\nまずは、どんな機能があるか見てみましょう！',
                    ),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    onTap: () => _showPaywall(context),
                  ),
                ),
                const Divider(height: 32),
              ],
              _buildSectionHeader('自動更新'),
              _buildSwitchTile(
                title: '自動スケジュール更新',
                subtitle: '交換日到来時に次周期へ自動更新',
                value: state.isPremium ? state.autoSchedule : false,
                activeColor: themeColor,
                badge: _premiumBadge(context),
                onChanged: (value) {
                  if (state.isPremium) {
                    state.setAutoSchedule(value);
                  } else {
                    _showPaywall(context);
                  }
                },
              ),
              if (!hasSecondProfile) ...[
                const Divider(height: 32),
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
                    onPressed: () async {
                      if (state.isPremium) {
                        await _showSecondContactDialog(context, state);
                      } else {
                        await _showPaywall(context);
                      }
                    },
                    icon: Icon(state.isPremium ? Icons.add : Icons.lock),
                    label: const Text(
                      '2つ目のコンタクトを登録 (Premium)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 32),
              ] else
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
              _buildSectionHeader('背景設定'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: state.availableBackgroundOptions.length,
                  itemBuilder: (context, index) {
                    final option = state.availableBackgroundOptions[index];
                    final isSelected = state.selectedBackgroundId == option.id ||
                        (state.selectedBackgroundId == null && option.isNone);
                    return _buildBackgroundOption(
                      option: option,
                      isSelected: isSelected,
                      accentColor: themeColor,
                      onTap: () => state.setSelectedBackground(
                        option.isNone ? null : option.id,
                      ),
                    );
                  },
                ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              ListTile(
                leading: Icon(Icons.star_rate_rounded, color: themeColor),
                title: const Text('評価・レビュー'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: () async {
                  final didRequest = await ReviewService().requestReview();
                  if (!didRequest) {
                    await Future.delayed(const Duration(seconds: 1));
                    if (!context.mounted) {
                      return;
                    }
                    await ReviewService()
                        .openStorePage(appStoreId: '6756917635');
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: themeColor),
                title: const Text('サブスクリプションの説明'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: () => _openSubscriptionExplanation(context),
              ),
              ListTile(
                leading: Icon(Icons.description_outlined, color: themeColor),
                title: const Text('利用規約'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: () => _openTermsPage(context),
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip_outlined, color: themeColor),
                title: const Text('プライバシーポリシー'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: () => _openPrivacyPolicyPage(context),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPaywall(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallPage()),
    );
  }

  Future<void> _openSubscriptionExplanation(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubscriptionExplanationPage()),
    );
  }

  Future<void> _openTermsPage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsPage()),
    );
  }

  Future<void> _openPrivacyPolicyPage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
    );
  }

  Future<void> _startInventoryOnboarding({
    required BuildContext context,
    required ContactLensState state,
  }) async {
    await state.dismissInventoryOnboarding();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InventoryOnboardingScreen()),
    );

    if (result == true && !state.showInventory) {
      await state.setShowInventory(true);
    }
  }

  Future<void> _dismissInventoryOnboarding(ContactLensState state) async {
    await state.dismissInventoryOnboarding();
  }

  Widget _premiumBadge(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Premium',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
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
    final step1 = await _showContactSetupStep(
      context,
      title: 'Step 1 / 2: 1つ目のコンタクト',
      initialName: state.profileName(0),
      initialLensType: state.profileLensType(0),
    );

    if (step1 == null) return;

    final step2 = await _showContactSetupStep(
      context,
      title: 'Step 2 / 2: 2つ目のコンタクト',
      initialName: state.profileName(1),
      initialLensType: state.profileLensType(1),
      confirmLabel: '登録',
    );

    if (step2 == null) return;

    await state.registerSecondProfile(
      primaryName: step1['name'] ?? '',
      primaryLensType: step1['lensType'] ?? '',
      secondaryName: step2['name'] ?? '',
      secondaryLensType: step2['lensType'] ?? '',
    );
  }

  Future<Map<String, String>?> _showContactSetupStep(
    BuildContext context, {
    required String title,
    required String initialName,
    required String initialLensType,
    String confirmLabel = '次へ',
  }) {
    const lensTypes = ['コンタクト', 'カラコン', '右', '左'];
    final controller = TextEditingController(text: initialName);
    var selectedLensType =
        lensTypes.contains(initialLensType) ? initialLensType : lensTypes.first;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final themeColor = Theme.of(dialogContext).colorScheme.primary;
            final isValid =
                controller.text.trim().isNotEmpty && selectedLensType.isNotEmpty;
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '名前',
                      hintText: '例：右目 / 日常用',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'レンズ種別',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final type in lensTypes)
                        ChoiceChip(
                          label: Text(type),
                          selected: selectedLensType == type,
                          selectedColor: themeColor.withOpacity(0.15),
                          onSelected: (_) => setState(() {
                            selectedLensType = type;
                          }),
                          labelStyle: TextStyle(
                            color: selectedLensType == type
                                ? themeColor
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: isValid
                      ? () {
                          Navigator.of(dialogContext).pop({
                            'name': controller.text.trim(),
                            'lensType': selectedLensType,
                          });
                        }
                      : null,
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
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

  String _formatSimpleDate(DateTime? date) {
    if (date == null) {
      return '未設定';
    }
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
    Widget? badge,
  }) {
    return SwitchListTile(
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (badge != null) badge,
        ],
      ),
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

  Widget _buildBackgroundOption({
    required BackgroundOption option,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final borderColor = isSelected ? accentColor : Colors.grey[300]!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: option.assetPath == null
                    ? Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Text(
                            '背景なし',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : Image.asset(
                        option.assetPath!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: accentColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _CycleRange {
  const _CycleRange({
    required this.min,
    required this.max,
    required this.defaultValue,
  });

  final int min;
  final int max;
  final int defaultValue;
}

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class SubscriptionExplanationPage extends StatelessWidget {
  const SubscriptionExplanationPage({
    super.key,
    this.showProceedAction = false,
  });

  final bool showProceedAction;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    const explanations = [
      '一部の機能はサブスクリプションで提供されます',
      '月額プラン / 年額プランがあること',
      '購入確定時に Apple ID に課金されること',
      'サブスクリプションは自動更新されること',
      '解約は Apple ID の設定画面から行えること',
      '無料トライアルがある場合、期間終了後に課金されること',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('サブスクリプションについて'),
        backgroundColor: themeColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ご確認ください',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'サブスクリプション購入前に、以下の内容をご確認ください。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ...explanations.map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'サブスクリプションの内容と併せて、以下の規約もご確認ください。',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              _PolicyLinkTile(
                icon: Icons.description_outlined,
                title: '利用規約',
                color: themeColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsPage()),
                ),
              ),
              const SizedBox(height: 8),
              _PolicyLinkTile(
                icon: Icons.privacy_tip_outlined,
                title: 'プライバシーポリシー',
                color: themeColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                ),
              ),
              if (showProceedAction) ...[
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('内容を確認しました'),
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

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    Widget bullet(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• '),
            Expanded(
              child: Text(
                text,
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
        backgroundColor: themeColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本規約は、個人開発アプリ「コンタクト交換管理」（以下「本アプリ」）の利用条件を定めるものです。本アプリを利用することで、本規約に同意したものとみなします。',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                '第1条（利用について）',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              bullet('本アプリは、コンタクトレンズ交換時期の管理を支援する目的で提供されます。'),
              bullet('利用に必要な通信費は利用者の負担となります。'),
              const SizedBox(height: 16),
              Text(
                '第2条（サブスクリプション）',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              bullet('本アプリの一部機能はサブスクリプションとして提供され、月額プランと年額プランをご用意しています。'),
              bullet('購入確定時にご利用のApple IDに課金されます。'),
              bullet('サブスクリプションは期間終了時に自動更新され、更新処理はAppleが行います。'),
              bullet('自動更新の停止や解約は、期間終了日の24時間前までにApple IDの設定画面から行ってください。'),
              bullet('無料トライアルを提供する場合、トライアル終了後に自動的に課金が開始されます。'),
              bullet('価格や提供内容は予告なく変更されることがあります。変更後も利用を継続した場合、変更に同意したものとみなします。'),
              const SizedBox(height: 16),
              Text(
                '第3条（免責）',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              bullet('本アプリの利用により生じたいかなる損害についても、開発者は責任を負いません。'),
              bullet('通知や記録の精度を保証するものではなく、最終的な確認は利用者自身の責任で行ってください。'),
              const SizedBox(height: 16),
              Text(
                '第4条（禁止事項）',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              bullet('本アプリのリバースエンジニアリング、再配布、商用利用を禁止します。'),
              bullet('本アプリを利用した不正行為や公序良俗に反する行為を禁止します。'),
              const SizedBox(height: 16),
              Text(
                '第5条（準拠法）',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              bullet('本規約は日本法を準拠法とし、本アプリに関する紛争は開発者の所在地を管轄する裁判所を第一審の専属的合意管轄とします。'),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    Widget bullet(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• '),
            Expanded(
              child: Text(
                text,
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('プライバシーポリシー'),
        backgroundColor: themeColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本プライバシーポリシーは、本アプリが取り扱う情報とその管理方針について定めるものです。利用者は本アプリを使用することで、本ポリシーに同意したものとみなします。',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'データの取り扱い',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              bullet('本アプリは氏名・メールアドレスなどの個人情報を外部に送信しません。'),
              bullet('アプリで入力・作成されたデータは、端末内のみに保存され、サーバー等へ送信されることはありません。'),
              bullet('外部サービス（Firebase、Analytics など）を利用していないため、利用者の行動データを収集することもありません。'),
              const SizedBox(height: 16),
              Text(
                '通知について',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              bullet('本アプリではローカル通知を使用し、交換日や在庫に関するリマインドを端末上で表示します。'),
              bullet('通知の利用には端末から通知権限の付与が必要です。設定からいつでも変更できます。'),
              const SizedBox(height: 16),
              Text(
                'お問い合わせ',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '本ポリシーに関するご質問は、アプリストアのサポート欄からご連絡ください。',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyLinkTile extends StatelessWidget {
  const _PolicyLinkTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallPageState extends State<PaywallPage> {
  bool _isLoading = true;
  String? _error;
  bool _didClose = false;

  static const _userFacingErrorMessage =
      '現在購入情報を取得できません（ストア設定前/テスト環境未設定の可能性があります）';

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await context.read<ContactLensState>().queryProducts();
    if (!mounted) return;

    final state = context.read<ContactLensState>();
    setState(() {
      _isLoading = false;
      _error = state.productLoadError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactLensState>(
      builder: (context, state, _) {
        if (state.isPremium && !_didClose) {
          _didClose = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          });
        }

        final themeColor = state.themeColor;
        final monthlyProduct =
            state.productForId(ContactLensState.premiumMonthlyProductId);
        final yearlyProduct =
            state.productForId(ContactLensState.premiumYearlyProductId);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Premium'),
            backgroundColor: themeColor,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premiumで快適に管理',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '面倒な管理を、もっとラクに。',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'まずは無料体験から',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '今すぐ始めても、2週間は無料で使えます',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FeatureCard(
                    icon: Image.asset(
                      'assets/icons/auto_schedule.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                    title: '自動スケジュール更新',
                    description: '交換日を自動で次周期へ更新して、入力の手間を減らします',
                    color: themeColor,
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    icon: Image.asset(
                      'assets/icons/multi_lens.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                    title: '2種類のレンズ管理',
                    description: 'カラコン×コンタクトなど2種類の交換周期を同時管理。左/右の管理にも便利',
                    color: themeColor,
                  ),
                  const SizedBox(height: 24),
                  if (monthlyProduct != null || yearlyProduct != null) ...[
                    if (monthlyProduct != null)
                      _PriceBox(
                        themeColor: themeColor,
                        title: '月額プラン',
                        price: monthlyProduct.price,
                        details: const [],
                      ),
                    if (monthlyProduct != null && yearlyProduct != null)
                      const SizedBox(height: 12),
                    if (yearlyProduct != null)
                      _PriceBox(
                        themeColor: themeColor,
                        title: '年額プラン',
                        price: yearlyProduct.price,
                        details: const [
                          '月あたり 約210円',
                          '月額プランより約30%お得',
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null)
                    _ErrorMessage(
                      message: _error!,
                      onRetry: _loadProduct,
                    ),
                  if (_error != null) const SizedBox(height: 16),
                  if (monthlyProduct != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _handlePurchase(monthlyProduct),
                      child: const Text('2週間無料で試す（月額プラン）'),
                    ),
                  if (monthlyProduct != null && yearlyProduct != null)
                    const SizedBox(height: 8),
                  if (yearlyProduct != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _handlePurchase(yearlyProduct),
                      child: const Text('2週間無料で試す（年額プラン）'),
                    ),
                  if (monthlyProduct != null || yearlyProduct != null)
                    const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _handleRestore,
                    child: const Text('購入を復元する'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePurchase(ProductDetails? product) async {
    if (_isLoading || product == null) {
      _showSnackBar(_userFacingErrorMessage);
      return;
    }

    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const SubscriptionExplanationPage(showProceedAction: true),
      ),
    );

    if (confirmed != true) {
      return;
    }

    final isAvailable = await InAppPurchase.instance.isAvailable();
    if (!isAvailable) {
      _showSnackBar(_userFacingErrorMessage);
      return;
    }
    context.read<ContactLensState>().purchasePremium(product);
  }

  void _handleRestore() {
    if (_isLoading) {
      _showSnackBar('現在購入情報を取得できません');
      return;
    }
    context.read<ContactLensState>().restorePurchases();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({
    required this.themeColor,
    required this.title,
    required this.price,
    required this.details,
  });

  final Color themeColor;
  final String title;
  final String price;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  detail,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[700]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final Widget icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Center(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconTheme(
                      data: IconThemeData(color: color, size: 44),
                      child: icon,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.redAccent),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected ? color : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}

class _CycleAdjustButton extends StatelessWidget {
  const _CycleAdjustButton({
    required this.icon,
    required this.isEnabled,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isEnabled ? color : Colors.grey[300];
    final iconColor = isEnabled ? Colors.white : Colors.grey[600];
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 32,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: iconColor, size: 20),
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
                    isCurrentInventory ? '現在の在庫' : '在庫アラート基準',
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
