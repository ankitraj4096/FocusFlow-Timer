import 'package:flutter/material.dart';

// Returns white or black based on the luminance of color for contrast
Color getTextColorForBackground(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}