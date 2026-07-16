import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart';
import '../services/firebase_service.dart';
import '../../features/auth/providers/auth_provider.dart';

// State Provider to handle Sidebar expansion
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarExpandedProvider);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width < AppSizes.desktopBreakpoint;
    final isMobile = size.width < AppSizes.tabletBreakpoint;

    // Automatically collapse sidebar on smaller screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wasExpanded = ref.read(sidebarExpandedProvider);
      if (isTablet && wasExpanded) {
        ref.read(sidebarExpandedProvider.notifier).state = false;
      }
    });


    return Scaffold(
      drawer: isMobile ? const Drawer(child: SidebarContent(isDrawer: true)) : null,
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/clinic_logo.jpg',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                  AppSizes.w8,
                  Expanded(
                    child: Text(
                      AppStrings.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                    ),
                  ),
                ],
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(color: AppColors.border),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isExpanded ? AppSizes.sidebarWidthExpanded : AppSizes.sidebarWidthCollapsed,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: AppColors.border, width: 1.5),
                ),
              ),
              child: const SidebarContent(isDrawer: false),
            ),
          ],
          Expanded(
            child: Container(
              color: AppColors.background,
              child: Column(
                children: [
                  // Top Info Banner for Demo/Mock Mode
                  if (!FirebaseService.isFirebaseAvailable) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p8),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        border: Border(
                          bottom: BorderSide(color: AppColors.primary, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 16),
                          AppSizes.w8,
                          const Expanded(
                            child: Text(
                              'Running in local Demo/Mock Mode. Ready for preview and operations! Edit firebase_options.dart to connect to Cloud Firestore.',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Main Page Child
                  Expanded(
                    child: SelectionArea(
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarContent extends ConsumerWidget {
  final bool isDrawer;

  const SidebarContent({super.key, required this.isDrawer});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarExpandedProvider) || isDrawer;
    final currentRoute = GoRouterState.of(context).uri.path;
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'Admin';

    Widget buildMenuItem({
      required IconData icon,
      required String label,
      required String path,
      required VoidCallback onTap,
    }) {
      final isSelected = currentRoute.startsWith(path);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 4.0),
        child: InkWell(
          onTap: () {
            if (isDrawer) Navigator.pop(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? AppSizes.p16 : 0,
              vertical: AppSizes.p12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
            child: Row(
              mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: AppSizes.iconMedium,
                ),
                if (isExpanded) ...[
                  AppSizes.w16,
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.titleLarge?.copyWith(
                        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Sidebar Top Header
        if (!isDrawer) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.p24, horizontal: AppSizes.p16),
            child: Row(
              mainAxisAlignment: isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
              children: [
                if (isExpanded) ...[
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppSizes.radiusSmall - 1),
                            child: Image.asset(
                              'assets/images/clinic_logo.jpg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        AppSizes.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.appName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                AppStrings.appSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall - 1),
                      child: Image.asset(
                        'assets/images/clinic_logo.jpg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
                if (isExpanded) ...[
                  IconButton(
                    onPressed: () => ref.read(sidebarExpandedProvider.notifier).state = false,
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          AppSizes.h16,
        ] else ...[
          // Drawer Top Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: AppSizes.p24),
            color: AppColors.primaryLight,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/clinic_logo.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                AppSizes.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.appName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        AppStrings.appSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSizes.h16,
        ],

        // Menu Navigation Items
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              buildMenuItem(
                icon: Icons.grid_view_rounded,
                label: AppStrings.menuDashboard,
                path: '/dashboard',
                onTap: () => context.go('/dashboard'),
              ),
              if (isAdmin)
                buildMenuItem(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Staff Management',
                  path: '/staff',
                  onTap: () => context.go('/staff'),
                ),
              buildMenuItem(
                icon: Icons.people_alt_rounded,
                label: isAdmin ? AppStrings.menuPatients : 'My Patients',
                path: '/patients',
                onTap: () => context.go('/patients'),
              ),
              buildMenuItem(
                icon: Icons.history_edu_rounded,
                label: isAdmin ? AppStrings.menuSessions : 'My Sessions',
                path: '/sessions',
                onTap: () => context.go('/sessions'),
              ),
              buildMenuItem(
                icon: Icons.account_balance_wallet_rounded,
                label: AppStrings.menuBilling,
                path: '/billing',
                onTap: () => context.go('/billing'),
              ),
              if (isAdmin)
                buildMenuItem(
                  icon: Icons.analytics_rounded,
                  label: AppStrings.menuReports,
                  path: '/reports',
                  onTap: () => context.go('/reports'),
                ),
              if (isAdmin)
                buildMenuItem(
                  icon: Icons.list_alt_rounded,
                  label: 'Activity Logs',
                  path: '/activity-logs',
                  onTap: () => context.go('/activity-logs'),
                ),
              // Optional Settings if it ever gets implemented
              // buildMenuItem(
              //   icon: Icons.settings_rounded,
              //   label: 'Settings',
              //   path: '/settings',
              //   onTap: () => {},
              // ),
            ],
          ),
        ),

        // Sidebar Footer Actions
        const Divider(height: 1),
        AppSizes.h8,
        if (!isExpanded && !isDrawer) ...[
          IconButton(
            onPressed: () => ref.read(sidebarExpandedProvider.notifier).state = true,
            icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ),
          AppSizes.h8,
        ],
        buildMenuItem(
          icon: Icons.logout_rounded,
          label: AppStrings.menuLogout,
          path: '/logout',
          onTap: () => _showLogoutDialog(context, ref),
        ),
        AppSizes.h16,
      ],
    );
  }
}
