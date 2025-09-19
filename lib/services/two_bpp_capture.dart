import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:skripsie/constants.dart';

/// Prompts the user to choose Camera or Gallery, then:
/// - Decodes image
/// - Resizes to [targetWidth]x[targetHeight]
/// - Converts to 2-bit grayscale (4 levels), optionally with ordered dithering
/// - Packs 4 pixels per byte
/// - Returns a Map with header + raw packed bytes
///
/// Example header:
/// {
///   'width': 64, 'height': 64, 'format': '2bpp', 'packed': true
/// }
///
/// Returns null if user cancels.
Future<Map<String, dynamic>?> pickOrCapture2bpp(
  BuildContext context, {
  int targetWidth = DEFAULT_IMAGE_WIDTH,
  int targetHeight = DEFAULT_IMAGE_HEIGHT,
  bool dither = true,
}) async {
  final source = await _askImageSource(context);
  if (source == null) return null;

  final picker = ImagePicker();
  final xfile = await picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048);
  if (xfile == null) return null;

  final originalBytes = await xfile.readAsBytes();

  final packed = _quantize2bppPacked(
    originalBytes,
    width: targetWidth,
    height: targetHeight,
    dither: dither,
  );

  return {
    'header': {
      'width': targetWidth,
      'height': targetHeight,
      'format': '2bpp',
      'packed': true,
    },
    'bytes': packed,
  };
}

Future<ImageSource?> _askImageSource(BuildContext context) async {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Camera'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Photo Library'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// Map 0..255 -> 0..3 (2-bit)
int _to2Bit(int gray) => (gray >> 6) & 0x03;

// Optional: 4x4 Bayer matrix for ordered dithering
const _bayer4x4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

Uint8List _quantize2bppPacked(
  Uint8List sourceBytes, {
  required int width,
  required int height,
  bool dither = true,
}) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw ArgumentError('Unable to decode image');
  }

  // Resize (average filter reduces aliasing for downscales)
  final resized = img.copyResize(
    decoded,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );

  final total = width * height;
  if (total % 4 != 0) {
    throw ArgumentError('width*height must be divisible by 4');
  }

  // Quantize to 2-bit
  final px2 = List<int>.filled(total, 0);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final c = resized.getPixel(x, y);
      final r = c.r;
      final g = c.g;
      final b = c.b;
      int gray = (0.299 * r + 0.587 * g + 0.114 * b).round();

      if (dither) {
        final t = _bayer4x4[y & 3][x & 3];
        final offset = (t - 8) * 2; // tweak strength as desired
        gray = (gray + offset).clamp(0, 255);
      }

      px2[y * width + x] = _to2Bit(gray);
    }
  }

  // Pack 4 pixels (2 bits each) per byte
  final out = Uint8List(total ~/ 4);
  for (int i = 0, j = 0; i < total; i += 4, j++) {
    final p0 = px2[i] & 0x03;
    final p1 = px2[i + 1] & 0x03;
    final p2 = px2[i + 2] & 0x03;
    final p3 = px2[i + 3] & 0x03;
    out[j] = (p0 << 6) | (p1 << 4) | (p2 << 2) | p3;
  }
  return out;
}

/// Build a preview (grayscale PNG source) from packed data.
/// `scale` = integer nearest-neighbor upscaling (e.g., 4 -> each pixel becomes 4x4)
img.Image previewFrom2bpp(Uint8List packed, int width, int height, {int scale = 4}) {
  final levels = [0, 85, 170, 255];
  final base = img.Image(width: width, height: height);

  int byteIndex = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x += 4) {
      final byte = packed[byteIndex++];
      final p0 = (byte >> 6) & 0x03;
      final p1 = (byte >> 4) & 0x03;
      final p2 = (byte >> 2) & 0x03;
      final p3 = byte & 0x03;

      final g0 = levels[p0];
      final g1 = levels[p1];
      final g2 = levels[p2];
      final g3 = levels[p3];

      base.setPixelRgb(x, y, g0, g0, g0);
      base.setPixelRgb(x + 1, y, g1, g1, g1);
      base.setPixelRgb(x + 2, y, g2, g2, g2);
      base.setPixelRgb(x + 3, y, g3, g3, g3);
    }
  }

  if (scale <= 1) return base;

  return img.copyResize(
    base,
    width: width * scale,
    height: height * scale,
    interpolation: img.Interpolation.nearest,
  );
}


