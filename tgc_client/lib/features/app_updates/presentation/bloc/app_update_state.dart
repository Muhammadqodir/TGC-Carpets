import 'package:equatable/equatable.dart';
import '../../domain/entities/app_release_entity.dart';

abstract class AppUpdateState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppUpdateInitial extends AppUpdateState {}

class AppUpdateChecking extends AppUpdateState {}

/// A newer version exists on the server.
class AppUpdateAvailable extends AppUpdateState {
  final AppReleaseEntity release;

  AppUpdateAvailable(this.release);

  @override
  List<Object?> get props => [release];
}

/// The installed version is already the latest.
class AppUpdateNotAvailable extends AppUpdateState {}

/// Downloading the update file. [progress] is 0.0–1.0.
class AppUpdateDownloading extends AppUpdateState {
  final double progress;

  AppUpdateDownloading(this.progress);

  @override
  List<Object?> get props => [progress];
}

/// File downloaded; system installer is being launched.
class AppUpdateInstalling extends AppUpdateState {}

/// Fatal error during check or install.
class AppUpdateError extends AppUpdateState {
  final String message;

  AppUpdateError(this.message);

  @override
  List<Object?> get props => [message];
}
