import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/controllers/navigation_controller.dart';
import 'package:ai_gym_flutter/controllers/sync_controller.dart';
import 'package:ai_gym_flutter/core/localization/app_localizations.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/core/widgets/svg_vector_icons.dart';
import 'package:ai_gym_flutter/models/app_user.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/notification_service.dart';
import 'package:ai_gym_flutter/services/preference_service.dart';
import 'package:ai_gym_flutter/widgets/rest_timer_banner.dart';

/// Responsive application shell supporting:
/// - `< 600px`: 5-Tab Bottom NavigationBar (`Home`, `Workout`, `Progress`, `Camera`, `More`)
/// - `600px–1024px`: Compact `NavigationRail`
/// - `> 1024px`: Extended `NavigationRail` with centered max-width content container
/// Also gates simulated iOS 18 Dynamic Island preview behind Developer Mode / Admin.
class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({
    super.key,
    required this.user,
    required this.prefs,
    required this.navigationController,
    required this.syncController,
    required this.cameraService,
    required this.notifications,
    required this.pages,
    required this.onSyncNow,
  });

  final AppUser user;
  final PreferenceService prefs;
  final NavigationController navigationController;
  final SyncController syncController;
  final CameraDetectionService cameraService;
  final NotificationService notifications;
  final List<Widget> pages;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context, prefs.languageCode);
    final isZh = strings.isZh;
    final glass = prefs.glassThemeEnabled;
    final showIosPreviewChrome =
        (prefs.developerModeEnabled || user.isAdmin) &&
        prefs.iosPreviewModeEnabled;

    return ListenableBuilder(
      listenable: navigationController,
      builder: (context, _) {
        final selectedIndex = navigationController.selectedIndex;
        final pageTitle = switch (selectedIndex) {
          1 => strings.tr('nav_workout'),
          2 => strings.tr('nav_progress'),
          3 => strings.tr('nav_camera'),
          4 => isZh ? '更多功能' : 'More',
          _ => strings.tr('nav_dashboard'),
        };

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= 1024;
            final isTablet = width >= 600 && width < 1024;

            return Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(showIosPreviewChrome ? 102 : 68),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIosPreviewChrome)
                      _DeveloperPreviewStatusBar(
                        cameraService: cameraService,
                        notifications: notifications,
                        isZh: isZh,
                        onTapCamera: () => navigationController.selectTab(3),
                      ),
                    AppBar(
                      title: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: AiGymSvgIcon(
                              AiGymSvgIconName.workoutDumbbell,
                              size: 23,
                              color: Theme.of(context).colorScheme.primary,
                              semanticLabel: 'AI Gym',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  pageTitle,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  strings.tr('app_title'),
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        letterSpacing: 0.6,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        // Sync and rest controls stay available from every destination.
                        ListenableBuilder(
                          listenable: syncController,
                          builder: (context, _) {
                            final pending = syncController.pendingCount;
                            final syncing = syncController.isSyncing;
                            return IconButton(
                              tooltip: isZh
                                  ? '雲端同步狀態 (待同步: $pending)'
                                  : 'Cloud Sync Status ($pending pending)',
                              onPressed: onSyncNow,
                              icon: Badge(
                                isLabelVisible: pending > 0,
                                label: Text('$pending'),
                                child: Icon(
                                  syncing
                                      ? Icons.sync
                                      : (syncController.isOnline
                                            ? Icons.cloud_done_outlined
                                            : Icons.cloud_off_outlined),
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                        ListenableBuilder(
                          listenable: notifications,
                          builder: (context, _) {
                            if (!notifications.isRunning) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                avatar: const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Color(0xFF30D158),
                                ),
                                label: Text(
                                  notifications.formattedRemaining,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: () =>
                                    navigationController.selectTab(1),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          key: const Key('appbar_settings_button'),
                          tooltip: strings.tr('nav_settings'),
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          onPressed: () => navigationController
                              .openMoreDestination(MoreSubDestination.settings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              body: GlassScaffoldBackground(
                glassEnabled: glass,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        if (isTablet || isDesktop)
                          NavigationRail(
                            extended: isDesktop,
                            selectedIndex: selectedIndex,
                            onDestinationSelected:
                                navigationController.selectTab,
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Icon(
                                user.isGuest
                                    ? Icons.person_outline
                                    : Icons.verified_user_outlined,
                                color: const Color(0xFF30D158),
                              ),
                            ),
                            destinations: [
                              NavigationRailDestination(
                                icon: const Icon(Icons.dashboard_outlined),
                                selectedIcon: const Icon(Icons.dashboard),
                                label: Text(strings.tr('nav_dashboard')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.fitness_center_outlined),
                                selectedIcon: const Icon(Icons.fitness_center),
                                label: Text(strings.tr('nav_workout')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.insights_outlined),
                                selectedIcon: const Icon(Icons.insights),
                                label: Text(strings.tr('nav_progress')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.videocam_outlined),
                                selectedIcon: const Icon(Icons.videocam),
                                label: Text(strings.tr('nav_camera')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.grid_view_outlined),
                                selectedIcon: const Icon(
                                  Icons.grid_view_rounded,
                                ),
                                label: Text(isZh ? '更多功能' : 'More'),
                              ),
                            ],
                          ),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isDesktop ? 1240 : double.infinity,
                              ),
                              child: IndexedStack(
                                index: selectedIndex,
                                children: pages,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: RestTimerBanner(
                        notificationService: notifications,
                        glassEnabled: glass,
                        isZh: isZh,
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: (isTablet || isDesktop)
                  ? null
                  : NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: navigationController.selectTab,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.dashboard_outlined),
                          selectedIcon: const Icon(Icons.dashboard),
                          label: strings.tr('nav_dashboard'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.fitness_center_outlined),
                          selectedIcon: const Icon(Icons.fitness_center),
                          label: strings.tr('nav_workout'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.insights_outlined),
                          selectedIcon: const Icon(Icons.insights),
                          label: strings.tr('nav_progress'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.videocam_outlined),
                          selectedIcon: const Icon(Icons.videocam),
                          label: strings.tr('nav_camera'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.grid_view_outlined),
                          selectedIcon: const Icon(Icons.grid_view_rounded),
                          label: isZh ? '更多' : 'More',
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class _DeveloperPreviewStatusBar extends StatelessWidget {
  const _DeveloperPreviewStatusBar({
    required this.cameraService,
    required this.notifications,
    required this.isZh,
    required this.onTapCamera,
  });

  final CameraDetectionService cameraService;
  final NotificationService notifications;
  final bool isZh;
  final VoidCallback onTapCamera;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cameraService, notifications]),
      builder: (context, _) {
        final toolbarText = notifications.isRunning
            ? '${notifications.formattedRemaining} • ${cameraService.formatToolbarStatus(isZh: isZh)}'
            : cameraService.formatToolbarStatus(isZh: isZh);

        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFF070A0F),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64D2FF),
                ),
              ),
              InkWell(
                onTap: onTapCamera,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sensors,
                        size: 12,
                        color: Color(0xFF30D158),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        toolbarText,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.developer_mode,
                size: 14,
                color: Color(0xFF98989F),
              ),
            ],
          ),
        );
      },
    );
  }
}
