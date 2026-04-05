// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// ignore_for_file: camel_case_types

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Win32 constants
// ---------------------------------------------------------------------------

/// PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS — enumerate local + connected
const int PRINTER_ENUM_LOCAL = 0x00000002;
const int PRINTER_ENUM_CONNECTIONS = 0x00000004;

// ---------------------------------------------------------------------------
// Win32 structs
// ---------------------------------------------------------------------------

/// DOC_INFO_1W — passed to StartDocPrinterW
final class DOC_INFO_1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

/// PRINTER_INFO_2W — returned by EnumPrintersW (level 2)
/// We only need pPrinterName, but must define the full struct layout
/// so that stride calculations are correct for array indexing.
final class PRINTER_INFO_2 extends Struct {
  external Pointer<Utf16> pServerName;
  external Pointer<Utf16> pPrinterName;
  external Pointer<Utf16> pShareName;
  external Pointer<Utf16> pPortName;
  external Pointer<Utf16> pDriverName;
  external Pointer<Utf16> pComment;
  external Pointer<Utf16> pLocation;
  external Pointer<Void> pDevMode;
  external Pointer<Utf16> pSepFile;
  external Pointer<Utf16> pPrintProcessor;
  external Pointer<Utf16> pDatatype;
  external Pointer<Utf16> pParameters;
  external Pointer<Void> pSecurityDescriptor;
  @Uint32()
  external int Attributes;
  @Uint32()
  external int Priority;
  @Uint32()
  external int DefaultPriority;
  @Uint32()
  external int StartTime;
  @Uint32()
  external int UntilTime;
  @Uint32()
  external int Status;
  @Uint32()
  external int cJobs;
  @Uint32()
  external int AveragePPM;
}

// ---------------------------------------------------------------------------
// Function typedefs for winspool.drv
// ---------------------------------------------------------------------------

// BOOL OpenPrinterW(LPCWSTR pPrinterName, LPHANDLE phPrinter, LPVOID pDefault)
typedef _OpenPrinterW_C = Int32 Function(
    Pointer<Utf16> pPrinterName,
    Pointer<IntPtr> phPrinter,
    Pointer<Void> pDefault);
typedef _OpenPrinterW_Dart = int Function(
    Pointer<Utf16> pPrinterName,
    Pointer<IntPtr> phPrinter,
    Pointer<Void> pDefault);

// BOOL ClosePrinter(HANDLE hPrinter)
typedef _ClosePrinter_C = Int32 Function(IntPtr hPrinter);
typedef _ClosePrinter_Dart = int Function(int hPrinter);

// DWORD StartDocPrinterW(HANDLE hPrinter, DWORD Level, LPBYTE pDocInfo)
typedef _StartDocPrinterW_C = Uint32 Function(
    IntPtr hPrinter, Uint32 level, Pointer<DOC_INFO_1> pDocInfo);
typedef _StartDocPrinterW_Dart = int Function(
    int hPrinter, int level, Pointer<DOC_INFO_1> pDocInfo);

// BOOL EndDocPrinter(HANDLE hPrinter)
typedef _EndDocPrinter_C = Int32 Function(IntPtr hPrinter);
typedef _EndDocPrinter_Dart = int Function(int hPrinter);

// BOOL StartPagePrinter(HANDLE hPrinter)
typedef _StartPagePrinter_C = Int32 Function(IntPtr hPrinter);
typedef _StartPagePrinter_Dart = int Function(int hPrinter);

// BOOL EndPagePrinter(HANDLE hPrinter)
typedef _EndPagePrinter_C = Int32 Function(IntPtr hPrinter);
typedef _EndPagePrinter_Dart = int Function(int hPrinter);

// BOOL WritePrinter(HANDLE hPrinter, LPVOID pBuf, DWORD cbBuf, LPDWORD pcWritten)
typedef _WritePrinter_C = Int32 Function(
    IntPtr hPrinter,
    Pointer<Void> pBuf,
    Uint32 cbBuf,
    Pointer<Uint32> pcWritten);
typedef _WritePrinter_Dart = int Function(
    int hPrinter,
    Pointer<Void> pBuf,
    int cbBuf,
    Pointer<Uint32> pcWritten);

// BOOL EnumPrintersW(DWORD Flags, LPWSTR Name, DWORD Level,
//   LPBYTE pPrinterEnum, DWORD cbBuf, LPDWORD pcbNeeded, LPDWORD pcReturned)
typedef _EnumPrintersW_C = Int32 Function(
    Uint32 flags,
    Pointer<Utf16> name,
    Uint32 level,
    Pointer<Uint8> pPrinterEnum,
    Uint32 cbBuf,
    Pointer<Uint32> pcbNeeded,
    Pointer<Uint32> pcReturned);
typedef _EnumPrintersW_Dart = int Function(
    int flags,
    Pointer<Utf16> name,
    int level,
    Pointer<Uint8> pPrinterEnum,
    int cbBuf,
    Pointer<Uint32> pcbNeeded,
    Pointer<Uint32> pcReturned);

// ---------------------------------------------------------------------------
// Win32 Printer API wrapper
// ---------------------------------------------------------------------------

/// Direct Win32 spooler API wrapper via dart:ffi.
///
/// Loads `winspool.drv` and provides:
///   - [enumPrinters] — fast printer discovery via EnumPrintersW
///   - [printRaw]     — send raw bytes via OpenPrinter → WritePrinter pipeline
///
/// This avoids PowerShell entirely, making both discovery and printing
/// near-instant even on low-end hardware (Celeron, etc.).
class Win32Printer {
  late final DynamicLibrary _winspool;

  late final _OpenPrinterW_Dart _openPrinter;
  late final _ClosePrinter_Dart _closePrinter;
  late final _StartDocPrinterW_Dart _startDocPrinter;
  late final _EndDocPrinter_Dart _endDocPrinter;
  late final _StartPagePrinter_Dart _startPagePrinter;
  late final _EndPagePrinter_Dart _endPagePrinter;
  late final _WritePrinter_Dart _writePrinter;
  late final _EnumPrintersW_Dart _enumPrinters;

  Win32Printer() {
    _winspool = DynamicLibrary.open('winspool.drv');

    _openPrinter = _winspool
        .lookupFunction<_OpenPrinterW_C, _OpenPrinterW_Dart>('OpenPrinterW');
    _closePrinter = _winspool
        .lookupFunction<_ClosePrinter_C, _ClosePrinter_Dart>('ClosePrinter');
    _startDocPrinter = _winspool
        .lookupFunction<_StartDocPrinterW_C, _StartDocPrinterW_Dart>(
            'StartDocPrinterW');
    _endDocPrinter = _winspool
        .lookupFunction<_EndDocPrinter_C, _EndDocPrinter_Dart>(
            'EndDocPrinter');
    _startPagePrinter = _winspool
        .lookupFunction<_StartPagePrinter_C, _StartPagePrinter_Dart>(
            'StartPagePrinter');
    _endPagePrinter = _winspool
        .lookupFunction<_EndPagePrinter_C, _EndPagePrinter_Dart>(
            'EndPagePrinter');
    _writePrinter = _winspool
        .lookupFunction<_WritePrinter_C, _WritePrinter_Dart>('WritePrinter');
    _enumPrinters = _winspool
        .lookupFunction<_EnumPrintersW_C, _EnumPrintersW_Dart>(
            'EnumPrintersW');
  }

  /// Enumerate installed printers using EnumPrintersW (level 2).
  ///
  /// Returns a list of printer names. This is instant — no PowerShell,
  /// no WMI, no process spawning.
  List<String> enumPrinters() {
    final pcbNeeded = calloc<Uint32>();
    final pcReturned = calloc<Uint32>();

    try {
      // First call: get required buffer size
      _enumPrinters(
        PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
        nullptr,
        2, // level 2 = PRINTER_INFO_2
        nullptr,
        0,
        pcbNeeded,
        pcReturned,
      );

      final bufferSize = pcbNeeded.value;
      if (bufferSize == 0) return [];

      // Allocate buffer and call again
      final pBuffer = calloc<Uint8>(bufferSize);
      try {
        final result = _enumPrinters(
          PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
          nullptr,
          2,
          pBuffer,
          bufferSize,
          pcbNeeded,
          pcReturned,
        );

        if (result == 0) return [];

        final count = pcReturned.value;
        final printers = <String>[];
        final structSize = sizeOf<PRINTER_INFO_2>();

        for (var i = 0; i < count; i++) {
          final info = Pointer<PRINTER_INFO_2>.fromAddress(
              pBuffer.address + i * structSize);
          final name = info.ref.pPrinterName;
          if (name != nullptr) {
            printers.add(name.toDartString());
          }
        }

        return printers;
      } finally {
        calloc.free(pBuffer);
      }
    } finally {
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    }
  }

  /// Send raw bytes to a printer using the Win32 spooler pipeline:
  ///   OpenPrinter → StartDocPrinter → StartPagePrinter →
  ///   WritePrinter → EndPagePrinter → EndDocPrinter → ClosePrinter
  ///
  /// [printerName] — system printer name (from [enumPrinters]).
  /// [data] — raw bytes to send (e.g., PNG file contents).
  /// [docName] — document name shown in the print queue.
  ///
  /// Returns `true` if all bytes were written successfully.
  bool printRaw({
    required String printerName,
    required Uint8List data,
    String docName = 'Label',
  }) {
    final pPrinterName = printerName.toNativeUtf16();
    final phPrinter = calloc<IntPtr>();

    try {
      // Open the printer
      final openResult = _openPrinter(pPrinterName, phPrinter, nullptr);
      if (openResult == 0) return false;

      final hPrinter = phPrinter.value;

      // Set up DOC_INFO_1 with RAW datatype
      final pDocInfo = calloc<DOC_INFO_1>();
      final pDocName = docName.toNativeUtf16();
      final pDatatype = 'RAW'.toNativeUtf16();

      pDocInfo.ref.pDocName = pDocName;
      pDocInfo.ref.pOutputFile = nullptr;
      pDocInfo.ref.pDatatype = pDatatype;

      try {
        // Start document
        final docId = _startDocPrinter(hPrinter, 1, pDocInfo);
        if (docId == 0) {
          _closePrinter(hPrinter);
          return false;
        }

        // Start page
        if (_startPagePrinter(hPrinter) == 0) {
          _endDocPrinter(hPrinter);
          _closePrinter(hPrinter);
          return false;
        }

        // Write data
        final pData = calloc<Uint8>(data.length);
        final pcWritten = calloc<Uint32>();
        try {
          // Copy Dart bytes into native memory
          for (var i = 0; i < data.length; i++) {
            pData[i] = data[i];
          }

          final writeResult = _writePrinter(
            hPrinter,
            pData.cast<Void>(),
            data.length,
            pcWritten,
          );

          final success = writeResult != 0 && pcWritten.value == data.length;

          // End page + doc + close (always clean up)
          _endPagePrinter(hPrinter);
          _endDocPrinter(hPrinter);
          _closePrinter(hPrinter);

          return success;
        } finally {
          calloc.free(pData);
          calloc.free(pcWritten);
        }
      } finally {
        calloc.free(pDocInfo);
        calloc.free(pDocName);
        calloc.free(pDatatype);
      }
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }
}
