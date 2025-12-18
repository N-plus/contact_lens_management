# contact_lens_management

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS app icon regeneration

When refreshing the iOS launcher icon with `flutter_launcher_icons`, use the
included 1024x1024 source image at `assets/app_icon_1024.png`. The current
configuration in `pubspec.yaml` already points `flutter_launcher_icons` at this
file with iOS enabled and Android disabled.

To regenerate the icon set on a machine that has Flutter available:

1. `flutter pub get`
2. `dart run flutter_launcher_icons`
3. Verify that the PNG variants and `Contents.json` update under
   `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
4. Clear iOS build caches before reinstalling:
   `flutter clean && flutter pub get && cd ios && pod install && cd ..`.

Note: the current container image does not include Flutter/Dart tooling and
cannot fetch it from the network, so the generation step must be run in a
Flutter-enabled environment.

## Manual testing checklist

- 未購入状態で自動スケジュール更新をONにしようとして、Paywallが表示されSwitchがOFFのままになることを確認する。
- 未購入状態で「2つ目のコンタクトを登録」をタップしてPaywallが表示されることを確認する。
- Premium購入後に自動スケジュール更新を操作でき、2つ目のコンタクトを登録できることを確認する。
- アプリを再起動しても購入状態が復元され、Premiumが維持されることを確認する。
- Paywallの「購入を復元する」ボタンが購入状態を復元することを確認する。
