import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:skripsie/services/two_bpp_capture.dart' show previewFrom2bpp;

/// Renders a preview of a packed 2-bpp image from a map:
/// {
///   'header': {'width': W, 'height': H, 'format': '2bpp', 'packed': true},
///   'bytes': Uint8List of length (W*H)/4
/// }
class TwoBppImageView extends StatelessWidget {
  const TwoBppImageView({
    super.key,
    required this.twoBppMap,
    this.width,
    this.height,
    this.pixelScale = 4,
    this.imageColor,
  });

  final Map<String, dynamic> twoBppMap;
  final double? width;
  final double? height;
  final int pixelScale;
  final Color? imageColor;

  @override
  Widget build(BuildContext context) {
    final header = (twoBppMap['header'] ?? {}) as Map;
    final bytes = twoBppMap['bytes'] as Uint8List?;

    if (bytes == null ||
        header['width'] == null ||
        header['height'] == null ||
        header['format'] != '2bpp') {
      return const SizedBox.shrink();
    }

    final w = header['width'] as int;
    final h = header['height'] as int;

    final preview = previewFrom2bpp(bytes, w, h, scale: pixelScale);
    final png = Uint8List.fromList(img.encodePng(preview));

    Widget image = Image.memory(
      png,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      isAntiAlias: false,
      fit: BoxFit.contain,
    );

    // Apply color filter if imageColor is specified
    if (imageColor != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          imageColor!,
          BlendMode.modulate,
        ),
        child: image,
      );
    }

    if (width == null && height == null) {
      return Container(
        child: image,
      );
    }

    return Container(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: image,
      ),
    );
  }
}
