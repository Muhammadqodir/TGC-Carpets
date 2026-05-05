import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ota_update/ota_update.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/usecases/check_for_update_usecase.dart';
import 'app_update_event.dart';
import 'app_update_state.dart';

class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  final CheckForUpdateUseCase checkForUpdateUseCase;
  final Dio dio;

  AppUpdateBloc({
    required this.checkForUpdateUseCase,
    required this.dio,
  }) : super(AppUpdateInitial()) {
    on<CheckForUpdateRequested>(_onCheckForUpdate);
    on<InstallUpdateRequested>(_onInstallUpdate);
  }

  // ── Check ─────────────────────────────────────────────────────────────────

  Future<void> _onCheckForUpdate(
    CheckForUpdateRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(AppUpdateChecking());

    final result = await checkForUpdateUseCase(
      platform: event.platform,
      currentBuildCode: event.currentBuildCode,
    );

    result.fold(
      (failure) => emit(AppUpdateError(failure.message)),
      (release) {
        if (release == null) {
          emit(AppUpdateNotAvailable());
        } else {
          emit(AppUpdateAvailable(release));
        }
      },
    );
  }

  // ── Install dispatcher ────────────────────────────────────────────────────

  Future<void> _onInstallUpdate(
    InstallUpdateRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    if (Platform.isAndroid) {
      await _installAndroid(event, emit);
    } else if (Platform.isWindows) {
      await _installWindows(event, emit);
    }
  }

  // ── Android — OTA update (download + install handled by ota_update plugin) ──

  Future<void> _installAndroid(
    InstallUpdateRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    try {
      final release = event.release;

      await emit.forEach<OtaEvent>(
        OtaUpdate().execute(
          release.url,
          destinationFilename: 'tgc_update.apk',
          sha256checksum: release.sha256,
        ),
        onData: (otaEvent) {
          switch (otaEvent.status) {
            case OtaStatus.DOWNLOADING:
              final pct = double.tryParse(otaEvent.value ?? '0') ?? 0.0;
              return AppUpdateDownloading(pct / 100.0);
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              return AppUpdateInstalling();
            case OtaStatus.CHECKSUM_ERROR:
              return AppUpdateError(
                'Fayl butunligi tekshiruvdan o\'tmadi (SHA-256 mos kelmadi).',
              );
            case OtaStatus.INSTALLATION_ERROR:
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CANCELED:
              return AppUpdateError(
                'Yangilash xatosi: ${otaEvent.status.name}',
              );
          }
        },
        onError: (error, _) => AppUpdateError(error.toString()),
      );
    } catch (e) {
      emit(AppUpdateError('Android yangilashda xatolik: $e'));
    }
  }

  // ── Windows — download EXE, verify SHA-256, run installer ─────────────────

  Future<void> _installWindows(
    InstallUpdateRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    final release = event.release;
    final tempDir  = await getTemporaryDirectory();
    final filePath = '${tempDir.path}${Platform.pathSeparator}tgc_update.exe';
    final tempFile = File(filePath);

    // Bridge Dio's callback-based progress into a Stream for emit.forEach
    final progressController = StreamController<double>();

    try {
      emit(AppUpdateDownloading(0));

      // Download runs concurrently with the forEach stream consumption below
      final downloadFuture = dio
          .download(
            release.url,
            filePath,
            onReceiveProgress: (received, total) {
              if (total > 0 && !progressController.isClosed) {
                progressController.add(received / total);
              }
            },
          )
          .then((_) => progressController.close())
          .catchError((Object e) {
            if (!progressController.isClosed) {
              progressController.addError(e);
              progressController.close();
            }
          });

      // Relay download progress to the UI
      await emit.forEach<double>(
        progressController.stream,
        onData: AppUpdateDownloading.new,
        onError: (error, _) => AppUpdateError(error.toString()),
      );

      // Rethrow any download error
      await downloadFuture;

      // ── SHA-256 verification ────────────────────────────────────────────
      // Stream the file to avoid loading a large EXE fully into memory
      final fileStream = tempFile.openRead();
      final digest = await crypto.sha256.bind(fileStream).first;

      if (digest.toString() != release.sha256.toLowerCase()) {
        emit(AppUpdateError(
          'Fayl butunligi tekshiruvdan o\'tmadi (SHA-256 mos kelmadi).',
        ));
        await _deleteSafely(tempFile);
        return;
      }

      // ── Launch detached installer ───────────────────────────────────────
      emit(AppUpdateInstalling());
      await Process.start(
        filePath,
        [],
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      emit(AppUpdateError('Windows yangilashda xatolik: $e'));
      await _deleteSafely(tempFile);
    } finally {
      if (!progressController.isClosed) {
        await progressController.close();
      }
    }
  }

  Future<void> _deleteSafely(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}


