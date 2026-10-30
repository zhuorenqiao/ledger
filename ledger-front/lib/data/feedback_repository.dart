import 'api_client.dart';

/// 意见反馈提交：一段正文 + 最多 [maxImages] 张图片。
///
/// 上限与服务端 `Feedback.MAX_CONTENT` / `Feedback.MAX_IMAGES` 对齐，
/// 前端先拦一次，省掉一次必然失败的请求。
class FeedbackRepository {
  const FeedbackRepository(this._api);

  final ApiClient _api;

  /// 正文最多 1000 字。
  static const maxContentLength = 1000;

  /// 最多 3 张图片。
  static const maxImages = 3;

  /// 反馈页本身就挂在已登录的首页下面，这里的 api 一定带得到 Bearer token。
  Future<void> submit({
    required String content,
    List<FormFile> images = const [],
  }) =>
      _api.postForm(
        '/api/feedback',
        fields: {'content': content},
        fileField: 'images',
        files: images,
      );
}
