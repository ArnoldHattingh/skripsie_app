import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageBwService {
  /// Process RGBA bytes into a 1-bit dithered black/white packed bitmap.
  /// - targetWidth/Height: e.g. 128x96 or 160x120
  /// Returns base64 of packed bytes.
  static String processToPackedB64({
    required Uint8List rgbaBytes,
    required int srcWidth,
    required int srcHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    // Decode RGBA into image package Image
    final src = img.Image.fromBytes(
      width: srcWidth,
      height: srcHeight,
      bytes: rgbaBytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    // Resize with cubic
    final resized = img.copyResize(
      src,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );

    // Contrast stretch
    final stretched = img.adjustColor(resized, contrast: 1.1, brightness: 0.02);

    // Convert to grayscale (luminance)
    final gray = img.grayscale(stretched);

    // Floyd–Steinberg dithering to 1-bit thresholded image
    final dithered = _floydSteinberg(gray);

    // Pack bits, MSB-first per byte, row-major
    final packed = _packBits(dithered, targetWidth, targetHeight);
    return base64Encode(packed);
  }

  static img.Image _floydSteinberg(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    // Work on float intensities 0..255
    final intens = List<double>.filled(w * h, 0);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = gray.getPixel(x, y);
        intens[y * w + x] = img.getLuminance(p).toDouble();
      }
    }
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = y * w + x;
        final old = intens[i];
        final newVal = old < 128 ? 0.0 : 255.0;
        final err = old - newVal;
        intens[i] = newVal;
        // Distribute error
        void add(int dx, int dy, double factor) {
          final nx = x + dx;
          final ny = y + dy;
          if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
            intens[ny * w + nx] = (intens[ny * w + nx] + err * factor)
                .clamp(0.0, 255.0);
          }
        }
        add(1, 0, 7 / 16);
        add(-1, 1, 3 / 16);
        add(0, 1, 5 / 16);
        add(1, 1, 1 / 16);
      }
    }
    // Build 1-bit image as 0/255 grayscale
    final out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final v = intens[y * w + x] >= 128 ? 255 : 0;
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }

  static Uint8List _packBits(img.Image bw, int w, int h) {
    final total = w * h;
    final out = Uint8List((total + 7) >> 3);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = y * w + x;
        final byteIndex = i >> 3;
        final bitIndex = 7 - (i & 7);
        final lum = img.getLuminance(bw.getPixel(x, y));
        final on = lum >= 128;
        if (on) {
          out[byteIndex] |= (1 << bitIndex);
        }
      }
    }
    return out;
  }
}


