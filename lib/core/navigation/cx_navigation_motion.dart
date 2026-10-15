import 'package:flutter/material.dart';

/// Centralized Motion Tokens & Physics Constants for CodeXa Navigation System
class CxNavigationMotion {
  // Animation Durations
  static const Duration tapTransitionDuration = Duration(milliseconds: 300);
  static const Duration releaseSettlingDuration = Duration(milliseconds: 360);
  static const Duration pressResponseDuration = Duration(milliseconds: 140);
  static const Duration iconEmphasisDuration = Duration(milliseconds: 160);

  // Curves
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve springSettleCurve = Curves.easeOutCubic;
  static const Curve pressCurve = Curves.easeOutQuad;

  // Gesture Thresholds
  static const double touchSlop =
      8.0; // Logical pixels to ignore accidental movements
  static const double velocityThreshold =
      350.0; // Pixels/second for fling/swipe gesture
  static const double boundaryHapticTolerance =
      0.12; // Fractional distance to trigger tick
}
