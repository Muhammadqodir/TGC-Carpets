import '../../domain/entities/app_release_entity.dart';

class AppReleaseModel extends AppReleaseEntity {
  const AppReleaseModel({
    required super.version,
    required super.buildCode,
    required super.isRequired,
    required super.url,
    required super.sha256,
    super.changelog,
  });

  factory AppReleaseModel.fromJson(Map<String, dynamic> json) {
    return AppReleaseModel(
      version:    json['version'] as String,
      buildCode:  (json['build_code'] as num).toInt(),
      isRequired: json['required'] as bool? ?? false,
      url:        json['url'] as String,
      sha256:     json['sha256'] as String,
      changelog:  json['changelog'] as String?,
    );
  }
}
