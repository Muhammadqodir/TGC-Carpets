import 'package:equatable/equatable.dart';

class AppReleaseEntity extends Equatable {
  final String version;
  final int buildCode;
  final bool isRequired;
  final String url;
  final String sha256;
  final String? changelog;

  const AppReleaseEntity({
    required this.version,
    required this.buildCode,
    required this.isRequired,
    required this.url,
    required this.sha256,
    this.changelog,
  });

  @override
  List<Object?> get props => [version, buildCode, isRequired, url, sha256, changelog];
}
