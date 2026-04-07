// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// ignore_for_file: camel_case_types

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Win32 constants
// ---------------------------------------------------------------------------

/// PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS
const int PRINTER_ENUM_LOCAL = 0x00000002;
const int PRINTER_ENUM_CONNECTIONS = 0x00000004;

/// GetDeviceCaps indices
const int HORZRES = 8; // printable width in pixels
const int VERTRES = 10; // printable height in pixels

/// GDI+ InterpolationMode
const int INTERPOLATION_HIGH_QUALITY_BICUBIC = 7;

/// GDI+ Unit — UnitPixel so coordinates match GetDeviceCaps pixels
const int UNIT_PIXEL = 2;

// ---------------------------------------------------------------------------
// Win32 structs
// ---------------------------------------------------------------------------

/// PRINTER_INFO_2W — returned by EnumPrintersW (level 2).
/// Full layout needed for correct stride when indexing the array.
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

/// DOCINFOW — passed to StartDocW (GDI printing).
final class DOCINFOW extends Struct {
  @Int32()
  external int cbSize;
  external Pointer<Utf16> lpszDocName;
  external Pointer<Utf16> lpszOutput;
  external Pointer<Utf16> lpszDatatype;
  @Uint32()
  external int fwType;
}

/// GdiplusStartupInput — passed to GdiplusStartup.
final class GdiplusStartupInput extends Struct {
  @Uint32()
  external int GdiplusVersion;
  external Pointer<Void> DebugEventCallback;
  @Int32()
  external int SuppressBackgroundThread;
  @Int32()
  external int SuppressExternalCodecs;
}

// ---------------------------------------------------------------------------
// Function typedefs — winspool.drv (printer enumeration only)
// ---------------------------------------------------------------------------

typedef _EnumPrintersW_C = Int32 Function(
    Uint32 flags, Pointer<Utf16> name, Uint32 level,
    Pointer<Uint8> pPrinterEnum, Uint32 cbBuf,
    Pointer<Uint32> pcbNeeded, Pointer<Uint32> pcReturned);
typedef _EnumPrintersW_Dart = int Function(
    int flags, Pointer<Utf16> name, int level,
    Pointer<Uint8> pPrinterEnum, int cbBuf,
    Pointer<Uint32> pcbNeeded, Pointer<Uint32> pcReturned);

// ---------------------------------------------------------------------------
// Function typedefs — gdi32.dll (printer DC + document/page management)
// ---------------------------------------------------------------------------

// HDC CreateDCW(LPCWSTR lpszDriver, LPCWSTR lpszDevice, ...)
typedef _CreateDCW_C = IntPtr Function(
    Pointer<Utf16> lpszDriver, Pointer<Utf16> lpszDevice,
    Pointer<Utf16> lpszOutput, Pointer<Void> lpInitData);
typedef _CreateDCW_Dart = int Function(
    Pointer<Utf16> lpszDriver, Pointer<Utf16> lpszDevice,
    Pointer<Utf16> lpszOutput, Pointer<Void> lpInitData);

// BOOL DeleteDC(HDC hdc)
typedef _DeleteDC_C = Int32 Function(IntPtr hdc);
typedef _DeleteDC_Dart = int Function(int hdc);

// int StartDocW(HDC hdc, const DOCINFOW* lpdi)
typedef _StartDocW_C = Int32 Function(IntPtr hdc, Pointer<DOCINFOW> lpdi);
typedef _StartDocW_Dart = int Function(int hdc, Pointer<DOCINFOW> lpdi);

// int StartPage(HDC hdc)
typedef _StartPage_C = Int32 Function(IntPtr hdc);
typedef _StartPage_Dart = int Function(int hdc);

// int EndPage(HDC hdc)
typedef _EndPage_C = Int32 Function(IntPtr hdc);
typedef _EndPage_Dart = int Function(int hdc);

// int EndDoc(HDC hdc)
typedef _EndDoc_C = Int32 Function(IntPtr hdc);
typedef _EndDoc_Dart = int Function(int hdc);

// int GetDeviceCaps(HDC hdc, int index)
typedef _GetDeviceCaps_C = Int32 Function(IntPtr hdc, Int32 index);
typedef _GetDeviceCaps_Dart = int Function(int hdc, int index);

// ---------------------------------------------------------------------------
// Function typedefs — gdiplus.dll (image loading + drawing)
// ---------------------------------------------------------------------------

// GpStatus GdiplusStartup(ULONG_PTR* token, GdiplusStartupInput* input, ...)
typedef _GdiplusStartup_C = Int32 Function(
    Pointer<IntPtr> token, Pointer<GdiplusStartupInput> input,
    Pointer<Void> output);
typedef _GdiplusStartup_Dart = int Function(
    Pointer<IntPtr> token, Pointer<GdiplusStartupInput> input,
    Pointer<Void> output);

// void GdiplusShutdown(ULONG_PTR token)
typedef _GdiplusShutdown_C = Void Function(IntPtr token);
typedef _GdiplusShutdown_Dart = void Function(int token);

// GpStatus GdipLoadImageFromFile(LPCWSTR filename, GpImage** image)
typedef _GdipLoadImageFromFile_C = Int32 Function(
    Pointer<Utf16> filename, Pointer<Pointer<Void>> image);
typedef _GdipLoadImageFromFile_Dart = int Function(
    Pointer<Utf16> filename, Pointer<Pointer<Void>> image);

// GpStatus GdipCreateFromHDC(HDC hdc, GpGraphics** graphics)
typedef _GdipCreateFromHDC_C = Int32 Function(
    IntPtr hdc, Pointer<Pointer<Void>> graphics);
typedef _GdipCreateFromHDC_Dart = int Function(
    int hdc, Pointer<Pointer<Void>> graphics);

// GpStatus GdipDrawImageRectI(GpGraphics*, GpImage*, INT x, y, w, h)
typedef _GdipDrawImageRectI_C = Int32 Function(
    Pointer<Void> graphics, Pointer<Void> image,
    Int32 x, Int32 y, Int32 width, Int32 height);
typedef _GdipDrawImageRectI_Dart = int Function(
    Pointer<Void> graphics, Pointer<Void> image,
    int x, int y, int width, int height);

// GpStatus GdipSetInterpolationMode(GpGraphics*, InterpolationMode)
typedef _GdipSetInterpolationMode_C = Int32 Function(
    Pointer<Void> graphics, Int32 mode);
typedef _GdipSetInterpolationMode_Dart = int Function(
    Pointer<Void> graphics, int mode);

// GpStatus GdipSetPageUnit(GpGraphics*, GpUnit unit)
typedef _GdipSetPageUnit_C = Int32 Function(
    Pointer<Void> graphics, Int32 unit);
typedef _GdipSetPageUnit_Dart = int Function(
    Pointer<Void> graphics, int unit);

// GpStatus GdipDeleteGraphics(GpGraphics*)
typedef _GdipDeleteGraphics_C = Int32 Function(Pointer<Void> graphics);
typedef _GdipDeleteGraphics_Dart = int Function(Pointer<Void> graphics);

// GpStatus GdipGetImageWidth(GpImage*, UINT* width)
typedef _GdipGetImageWidth_C = Int32 Function(
    Pointer<Void> image, Pointer<Uint32> width);
typedef _GdipGetImageWidth_Dart = int Function(
    Pointer<Void> image, Pointer<Uint32> width);

// GpStatus GdipGetImageHeight(GpImage*, UINT* height)
typedef _GdipGetImageHeight_C = Int32 Function(
    Pointer<Void> image, Pointer<Uint32> height);
typedef _GdipGetImageHeight_Dart = int Function(
    Pointer<Void> image, Pointer<Uint32> height);

// GpStatus GdipDisposeImage(GpImage*)
typedef _GdipDisposeImage_C = Int32 Function(Pointer<Void> image);
typedef _GdipDisposeImage_Dart = int Function(Pointer<Void> image);

// ---------------------------------------------------------------------------
// Win32Printer — printer enumeration + GDI printing via dart:ffi
// ---------------------------------------------------------------------------

/// Direct Win32 API wrapper via dart:ffi.
///
/// Provides:
///   - [enumPrinters] — instant printer discovery via EnumPrintersW
///   - [printImage]   — print an image file through the printer driver
///                      using GDI+ (CreateDC → GdipDrawImageRectI)
///
/// No PowerShell, no process spawning, near-instant on any hardware.
class Win32Printer {
  // -- DLL handles --
  late final DynamicLibrary _winspool;
  late final DynamicLibrary _gdi32;
  late final DynamicLibrary _gdiplus;

  // -- winspool.drv functions --
  late final _EnumPrintersW_Dart _enumPrinters;

  // -- gdi32.dll functions --
  late final _CreateDCW_Dart _createDC;
  late final _DeleteDC_Dart _deleteDC;
  late final _StartDocW_Dart _startDoc;
  late final _StartPage_Dart _startPage;
  late final _EndPage_Dart _endPage;
  late final _EndDoc_Dart _endDoc;
  late final _GetDeviceCaps_Dart _getDeviceCaps;

  // -- gdiplus.dll functions --
  late final _GdiplusStartup_Dart _gdipStartup;
  late final _GdiplusShutdown_Dart _gdipShutdown;
  late final _GdipLoadImageFromFile_Dart _gdipLoadImage;
  late final _GdipCreateFromHDC_Dart _gdipCreateFromHDC;
  late final _GdipDrawImageRectI_Dart _gdipDrawImageRectI;
  late final _GdipSetInterpolationMode_Dart _gdipSetInterpolationMode;
  late final _GdipSetPageUnit_Dart _gdipSetPageUnit;
  late final _GdipDeleteGraphics_Dart _gdipDeleteGraphics;
  late final _GdipGetImageWidth_Dart _gdipGetImageWidth;
  late final _GdipGetImageHeight_Dart _gdipGetImageHeight;
  late final _GdipDisposeImage_Dart _gdipDisposeImage;

  Win32Printer() {
    // Load DLLs
    _winspool = DynamicLibrary.open('winspool.drv');
    _gdi32 = DynamicLibrary.open('gdi32.dll');
    _gdiplus = DynamicLibrary.open('gdiplus.dll');

    // winspool.drv
    _enumPrinters = _winspool
        .lookupFunction<_EnumPrintersW_C, _EnumPrintersW_Dart>(
            'EnumPrintersW');

    // gdi32.dll
    _createDC = _gdi32
        .lookupFunction<_CreateDCW_C, _CreateDCW_Dart>('CreateDCW');
    _deleteDC = _gdi32
        .lookupFunction<_DeleteDC_C, _DeleteDC_Dart>('DeleteDC');
    _startDoc = _gdi32
        .lookupFunction<_StartDocW_C, _StartDocW_Dart>('StartDocW');
    _startPage = _gdi32
        .lookupFunction<_StartPage_C, _StartPage_Dart>('StartPage');
    _endPage = _gdi32
        .lookupFunction<_EndPage_C, _EndPage_Dart>('EndPage');
    _endDoc = _gdi32
        .lookupFunction<_EndDoc_C, _EndDoc_Dart>('EndDoc');
    _getDeviceCaps = _gdi32
        .lookupFunction<_GetDeviceCaps_C, _GetDeviceCaps_Dart>(
            'GetDeviceCaps');

    // gdiplus.dll
    _gdipStartup = _gdiplus
        .lookupFunction<_GdiplusStartup_C, _GdiplusStartup_Dart>(
            'GdiplusStartup');
    _gdipShutdown = _gdiplus
        .lookupFunction<_GdiplusShutdown_C, _GdiplusShutdown_Dart>(
            'GdiplusShutdown');
    _gdipLoadImage = _gdiplus
        .lookupFunction<_GdipLoadImageFromFile_C,
            _GdipLoadImageFromFile_Dart>('GdipLoadImageFromFile');
    _gdipCreateFromHDC = _gdiplus
        .lookupFunction<_GdipCreateFromHDC_C, _GdipCreateFromHDC_Dart>(
            'GdipCreateFromHDC');
    _gdipDrawImageRectI = _gdiplus
        .lookupFunction<_GdipDrawImageRectI_C, _GdipDrawImageRectI_Dart>(
            'GdipDrawImageRectI');
    _gdipSetInterpolationMode = _gdiplus
        .lookupFunction<_GdipSetInterpolationMode_C,
            _GdipSetInterpolationMode_Dart>('GdipSetInterpolationMode');
    _gdipSetPageUnit = _gdiplus
        .lookupFunction<_GdipSetPageUnit_C, _GdipSetPageUnit_Dart>(
            'GdipSetPageUnit');
    _gdipDeleteGraphics = _gdiplus
        .lookupFunction<_GdipDeleteGraphics_C, _GdipDeleteGraphics_Dart>(
            'GdipDeleteGraphics');
    _gdipGetImageWidth = _gdiplus
        .lookupFunction<_GdipGetImageWidth_C, _GdipGetImageWidth_Dart>(
            'GdipGetImageWidth');
    _gdipGetImageHeight = _gdiplus
        .lookupFunction<_GdipGetImageHeight_C, _GdipGetImageHeight_Dart>(
            'GdipGetImageHeight');
    _gdipDisposeImage = _gdiplus
        .lookupFunction<_GdipDisposeImage_C, _GdipDisposeImage_Dart>(
            'GdipDisposeImage');
  }

  // -------------------------------------------------------------------------
  // Printer enumeration
  // -------------------------------------------------------------------------

  /// Enumerate installed printers using EnumPrintersW (level 2).
  ///
  /// Returns a list of printer names. Instant — no process spawning.
  List<String> enumPrinters() {
    final pcbNeeded = calloc<Uint32>();
    final pcReturned = calloc<Uint32>();

    try {
      // First call: get required buffer size
      _enumPrinters(
        PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
        nullptr, 2, nullptr, 0, pcbNeeded, pcReturned,
      );

      final bufferSize = pcbNeeded.value;
      if (bufferSize == 0) return [];

      // Allocate buffer and call again
      final pBuffer = calloc<Uint8>(bufferSize);
      try {
        final result = _enumPrinters(
          PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
          nullptr, 2, pBuffer, bufferSize, pcbNeeded, pcReturned,
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

  // -------------------------------------------------------------------------
  // GDI+ image printing — goes through the printer driver
  // -------------------------------------------------------------------------

  /// Print an image file to the specified printer using GDI+.
  ///
  /// Flow:
  ///   1. Initialize GDI+
  ///   2. Load image from file (supports PNG, BMP, JPEG, etc.)
  ///   3. Open a printer device context (DC) via CreateDCW
  ///   4. StartDoc → StartPage
  ///   5. Draw the image scaled to fill the printable area
  ///   6. EndPage → EndDoc → cleanup
  ///
  /// This goes through the printer driver, so the driver handles
  /// rendering and communication with the hardware. Works with all
  /// printers that have a Windows driver installed.
  ///
  /// Returns `true` if the print job was sent successfully.
  bool printImage({
    required String printerName,
    required String filePath,
    String docName = 'Label',
    int copies = 1,
  }) {
    if (copies < 1) copies = 1;
    // -- 1. Initialize GDI+ --
    final pToken = calloc<IntPtr>();
    final pStartupInput = calloc<GdiplusStartupInput>();
    pStartupInput.ref.GdiplusVersion = 1;
    pStartupInput.ref.DebugEventCallback = nullptr;
    pStartupInput.ref.SuppressBackgroundThread = 0;
    pStartupInput.ref.SuppressExternalCodecs = 0;

    var status = _gdipStartup(pToken, pStartupInput, nullptr);
    if (status != 0) {
      calloc.free(pToken);
      calloc.free(pStartupInput);
      return false;
    }
    final gdipToken = pToken.value;
    calloc.free(pStartupInput);

    // -- 2. Load image from file --
    final pFilePath = filePath.toNativeUtf16();
    final ppImage = calloc<Pointer<Void>>();

    status = _gdipLoadImage(pFilePath, ppImage);
    calloc.free(pFilePath);

    if (status != 0) {
      calloc.free(ppImage);
      _gdipShutdown(gdipToken);
      calloc.free(pToken);
      return false;
    }
    final hImage = ppImage.value;
    calloc.free(ppImage);

    // -- 3. Create printer DC --
    final pDriver = 'WINSPOOL'.toNativeUtf16();
    final pDevice = printerName.toNativeUtf16();

    final hdc = _createDC(pDriver, pDevice, nullptr, nullptr);
    calloc.free(pDriver);
    calloc.free(pDevice);

    if (hdc == 0) {
      _gdipDisposeImage(hImage);
      _gdipShutdown(gdipToken);
      calloc.free(pToken);
      return false;
    }

    // Get printable area size from the printer DC
    final pageWidth = _getDeviceCaps(hdc, HORZRES);
    final pageHeight = _getDeviceCaps(hdc, VERTRES);

    // Get actual image dimensions for aspect-ratio-preserving scaling
    final pImgWidth = calloc<Uint32>();
    final pImgHeight = calloc<Uint32>();
    _gdipGetImageWidth(hImage, pImgWidth);
    _gdipGetImageHeight(hImage, pImgHeight);
    final imgWidth = pImgWidth.value;
    final imgHeight = pImgHeight.value;
    calloc.free(pImgWidth);
    calloc.free(pImgHeight);

    // -- 4. Start document --
    final pDocInfo = calloc<DOCINFOW>();
    final pDocName = docName.toNativeUtf16();
    pDocInfo.ref.cbSize = sizeOf<DOCINFOW>();
    pDocInfo.ref.lpszDocName = pDocName;
    pDocInfo.ref.lpszOutput = nullptr;
    pDocInfo.ref.lpszDatatype = nullptr;
    pDocInfo.ref.fwType = 0;

    final docResult = _startDoc(hdc, pDocInfo);
    calloc.free(pDocInfo);
    calloc.free(pDocName);

    if (docResult <= 0) {
      _deleteDC(hdc);
      _gdipDisposeImage(hImage);
      _gdipShutdown(gdipToken);
      calloc.free(pToken);
      return false;
    }

    // -- 5. Pre-calculate destination rect (shared across all copies) --
    int destX = 0, destY = 0, destW = pageWidth, destH = pageHeight;
    if (imgWidth > 0 && imgHeight > 0) {
      final scaleX = pageWidth / imgWidth;
      final scaleY = pageHeight / imgHeight;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      destW = (imgWidth * scale).round();
      destH = (imgHeight * scale).round();
      destX = (pageWidth - destW) ~/ 2;
      destY = (pageHeight - destH) ~/ 2;
    }

    // -- 6. Print one page per copy inside the same document --
    bool success = false;
    for (int copy = 0; copy < copies; copy++) {
      if (_startPage(hdc) <= 0) break;

      final ppGraphics = calloc<Pointer<Void>>();
      status = _gdipCreateFromHDC(hdc, ppGraphics);

      if (status == 0) {
        final hGraphics = ppGraphics.value;

        // Set page unit to pixels so coordinates match GetDeviceCaps values.
        _gdipSetPageUnit(hGraphics, UNIT_PIXEL);

        // Set high quality interpolation for crisp output.
        _gdipSetInterpolationMode(hGraphics, INTERPOLATION_HIGH_QUALITY_BICUBIC);

        // Draw image scaled to fit, centered on the page.
        status = _gdipDrawImageRectI(
            hGraphics, hImage, destX, destY, destW, destH);
        success = (status == 0);

        _gdipDeleteGraphics(hGraphics);
      }
      calloc.free(ppGraphics);

      _endPage(hdc);

      if (!success) break;
    }

    // -- 7. End document --
    _endDoc(hdc);

    // -- 8. Cleanup --
    _deleteDC(hdc);
    _gdipDisposeImage(hImage);
    _gdipShutdown(gdipToken);
    calloc.free(pToken);

    return success;
  }
}
