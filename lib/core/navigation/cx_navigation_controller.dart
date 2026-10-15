import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cx_navigation_motion.dart';

enum CodeXaNavigationState {
  idle,
  pressing,
  draggingNavBar,
  draggingPage,
  settling,
  programmatic,
}

/// Unified Single Controller for CodeXa 5-Tab Navigation System.
/// Authoritative state manager synchronizing:
/// 1. Bottom Liquid Glass Capsule scrubber
/// 2. Full-Screen horizontal PageView
/// 3. GoRouter location and haptics
class CodeXaNavigationController extends ChangeNotifier {
  final PageController pageController;
  final void Function(int targetIndex)? onTabCommitted;

  int _currentIndex;
  double _fractionalIndex;
  CodeXaNavigationState _state = CodeXaNavigationState.idle;

  // Gesture Tracking Internals
  VelocityTracker? _velocityTracker;
  double _pointerDownX = 0.0;
  Duration? _pointerDownTime;
  bool _hasCrossedTouchSlop = false;
  int _lastHapticInteger = 0;

  CodeXaNavigationController({int initialIndex = 0, this.onTabCommitted})
    : _currentIndex = initialIndex,
      _fractionalIndex = initialIndex.toDouble(),
      _lastHapticInteger = initialIndex,
      pageController = PageController(initialPage: initialIndex);

  int get currentIndex => _currentIndex;
  double get fractionalIndex => _fractionalIndex;
  CodeXaNavigationState get state => _state;
  bool get isDraggingNavBar => _state == CodeXaNavigationState.draggingNavBar;
  bool get isDraggingPage => _state == CodeXaNavigationState.draggingPage;

  /// External sync when route changes from outside (e.g. deep link or back nav)
  void syncWithRouteIndex(int routeIndex) {
    if (routeIndex < 0 || routeIndex > 4) {
      return;
    }
    if (_currentIndex == routeIndex && _state == CodeXaNavigationState.idle) {
      return;
    }

    if (_state != CodeXaNavigationState.draggingNavBar &&
        _state != CodeXaNavigationState.draggingPage) {
      _currentIndex = routeIndex;
      _fractionalIndex = routeIndex.toDouble();
      _lastHapticInteger = routeIndex;

      if (pageController.hasClients &&
          (pageController.page?.round() != routeIndex)) {
        pageController.jumpToPage(routeIndex);
      }
      notifyListeners();
    }
  }

  /// Mode B: Called when user is swiping the full-screen PageView
  void onPageScrolled(double page) {
    if (_state == CodeXaNavigationState.draggingNavBar) {
      return;
    }

    _fractionalIndex = page.clamp(0.0, 4.0);
    _checkBoundaryHaptics(_fractionalIndex);
    notifyListeners();
  }

  /// Mode B: Called when full-screen PageView finishes settling
  void onPageScrollEnded(int settledIndex) {
    if (_state == CodeXaNavigationState.draggingNavBar) {
      return;
    }

    _state = CodeXaNavigationState.idle;
    if (_currentIndex != settledIndex) {
      _currentIndex = settledIndex;
      _fractionalIndex = settledIndex.toDouble();
      _lastHapticInteger = settledIndex;
      HapticFeedback.lightImpact();
      onTabCommitted?.call(settledIndex);
      notifyListeners();
    }
  }

  double _getLocalX(PointerEvent event) {
    if (event.localPosition != Offset.zero) {
      return event.localPosition.dx;
    }
    return event.position.dx;
  }

  /// Mode A: Pointer down on the bottom navigation bar
  void onNavBarPointerDown(PointerDownEvent event, double barWidth) {
    _pointerDownX = _getLocalX(event);
    _pointerDownTime = event.timeStamp;
    _hasCrossedTouchSlop = false;
    _state = CodeXaNavigationState.pressing;

    _velocityTracker = VelocityTracker.withKind(PointerDeviceKind.touch);
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    notifyListeners();
  }

  /// Mode A: Finger moves horizontally along bottom navigation bar
  void onNavBarPointerMove(PointerMoveEvent event, double barWidth) {
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final currentX = _getLocalX(event);
    final dx = (currentX - _pointerDownX).abs();
    if (!_hasCrossedTouchSlop) {
      if (dx >= CxNavigationMotion.touchSlop) {
        _hasCrossedTouchSlop = true;
        _state = CodeXaNavigationState.draggingNavBar;
      }
    }

    if (_hasCrossedTouchSlop) {
      final tabWidth = barWidth / 5.0;
      if (tabWidth > 0) {
        // Map pointer position to fractional tab [0.0, 4.0]
        final computedFrac = (currentX / tabWidth) - 0.5;
        _fractionalIndex = computedFrac.clamp(0.0, 4.0);

        _checkBoundaryHaptics(_fractionalIndex);

        // Move PageView synchronously to track finger continuously
        if (pageController.hasClients &&
            pageController.position.hasContentDimensions) {
          final viewport = pageController.position.viewportDimension;
          final targetPixels = _fractionalIndex * viewport;
          pageController.jumpTo(
            targetPixels.clamp(0.0, pageController.position.maxScrollExtent),
          );
        }

        notifyListeners();
      }
    }
  }

  /// Mode A: User releases pointer from bottom navigation bar
  void onNavBarPointerUp(PointerUpEvent event, double barWidth) {
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final velocityEstimate = _velocityTracker?.getVelocity() ?? Velocity.zero;
    var velocityX = velocityEstimate.pixelsPerSecond.dx;

    final currentX = _getLocalX(event);

    // Deterministic velocity fallback for fast flicks / few samples
    if (velocityX == 0.0 && _pointerDownTime != null) {
      final elapsedMs = (event.timeStamp - _pointerDownTime!).inMilliseconds;
      if (elapsedMs > 0) {
        final totalDx = currentX - _pointerDownX;
        velocityX = (totalDx / elapsedMs) * 1000.0;
      }
    }

    if (!_hasCrossedTouchSlop) {
      // Tap on a specific tab
      final tabWidth = barWidth / 5.0;
      final tappedIndex = (currentX / tabWidth).floor().clamp(0, 4);
      animateToTab(tappedIndex);
      return;
    }

    // Scrub release physics
    int targetIndex;
    if (velocityX.abs() >= CxNavigationMotion.velocityThreshold) {
      if (velocityX > 0) {
        targetIndex = _fractionalIndex.ceil().clamp(0, 4);
      } else {
        targetIndex = _fractionalIndex.floor().clamp(0, 4);
      }
    } else {
      targetIndex = _fractionalIndex.round().clamp(0, 4);
    }

    _settleToTab(targetIndex);
  }

  /// Mode A: Gesture cancelled (interrupted by phone call, notification, etc.)
  void onNavBarPointerCancel(PointerCancelEvent event) {
    _settleToTab(_currentIndex);
  }

  /// Direct Tab Tap or Release Settling Animation
  void animateToTab(int targetIndex) {
    if (targetIndex < 0 || targetIndex > 4) {
      return;
    }
    _settleToTab(targetIndex);
  }

  void _settleToTab(int targetIndex) {
    _state = CodeXaNavigationState.settling;
    _currentIndex = targetIndex;
    _lastHapticInteger = targetIndex;

    HapticFeedback.lightImpact();
    onTabCommitted?.call(targetIndex);

    if (pageController.hasClients) {
      pageController
          .animateToPage(
            targetIndex,
            duration: CxNavigationMotion.releaseSettlingDuration,
            curve: CxNavigationMotion.springSettleCurve,
          )
          .then((_) {
            _state = CodeXaNavigationState.idle;
            _fractionalIndex = targetIndex.toDouble();
            notifyListeners();
          });
    } else {
      _state = CodeXaNavigationState.idle;
      _fractionalIndex = targetIndex.toDouble();
      notifyListeners();
    }
  }

  void _checkBoundaryHaptics(double fractional) {
    final nearest = fractional.round();
    final dist = (fractional - nearest).abs();
    if (nearest != _lastHapticInteger &&
        dist <= CxNavigationMotion.boundaryHapticTolerance) {
      _lastHapticInteger = nearest;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
