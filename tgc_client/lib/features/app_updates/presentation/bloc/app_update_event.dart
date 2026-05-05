import 'package:equatable/equatable.dart';
import '../../domain/entities/app_release_entity.dart';

abstract class AppUpdateEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Triggers an update check against the server.
/// [currentBuildCode] is the build number of the currently running app.
class CheckForUpdateRequested extends AppUpdateEvent {
  final int currentBuildCode;
  final String platform;

  CheckForUpdateRequested({
    required this.currentBuildCode,
    required this.platform,
  });

  @override
  List<Object?> get props => [currentBuildCode, platform];
}

/// Triggers download + installation of the given release.
class InstallUpdateRequested extends AppUpdateEvent {
  final AppReleaseEntity release;

  InstallUpdateRequested(this.release);

  @override
  List<Object?> get props => [release];
}
