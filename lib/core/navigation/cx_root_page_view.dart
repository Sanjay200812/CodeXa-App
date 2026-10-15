import 'package:flutter/material.dart';

import 'cx_navigation_controller.dart';
import '../../features/home/home_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/messages/messages_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/projects/projects_screen.dart';

/// Coordinated 5-Tab Root PageView connected to CodeXaNavigationController.
/// Preserves child screen state and scroll positions while supporting full-screen swiping.
class CodeXaRootPageView extends StatelessWidget {
  final CodeXaNavigationController controller;

  const CodeXaRootPageView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (controller.pageController.hasClients &&
              controller.pageController.position.hasContentDimensions) {
            final page = controller.pageController.page;
            if (page != null) {
              controller.onPageScrolled(page);
            }
          }
        } else if (notification is ScrollEndNotification) {
          if (controller.pageController.hasClients) {
            final settledIndex =
                controller.pageController.page?.round().clamp(0, 4) ??
                controller.currentIndex;
            controller.onPageScrollEnded(settledIndex);
          }
        }
        return false;
      },
      child: PageView(
        controller: controller.pageController,
        physics: const BouncingScrollPhysics(),
        children: const [
          _KeepAliveTabWrapper(child: HomeScreen()),
          _KeepAliveTabWrapper(child: AttendanceScreen()),
          _KeepAliveTabWrapper(child: MessagesScreen()),
          _KeepAliveTabWrapper(child: FeedScreen()),
          _KeepAliveTabWrapper(child: ProjectsScreen()),
        ],
      ),
    );
  }
}

class _KeepAliveTabWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveTabWrapper({required this.child});

  @override
  State<_KeepAliveTabWrapper> createState() => _KeepAliveTabWrapperState();
}

class _KeepAliveTabWrapperState extends State<_KeepAliveTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
