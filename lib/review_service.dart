import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

class ReviewService {
  ReviewService({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  /// Apple公式のレビューUIを表示します。
  ///
  /// requestReview() はApple側の判断で表示されない場合があります。
  /// （例: 頻繁な表示、評価数上限、OS側の条件など）
  Future<bool> requestReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) {
        return false;
      }
      await _inAppReview.requestReview();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to request review: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// App Storeのレビュー/ストアページを直接開きます。
  ///
  /// iOSでは appStoreId が必須です。
  Future<void> openStorePage({
    required String appStoreId,
    String? microsoftStoreId,
  }) async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to open store listing: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

// 呼び出し例:
// - 購入完了後など、ユーザーが価値を感じたタイミングで実行する
//   ReviewService().requestReview();
//
// - 設定画面のボタンなどから手動でレビュー導線を用意する
//   ReviewService().openStorePage(appStoreId: '123456789');
