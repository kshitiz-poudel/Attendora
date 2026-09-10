import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers.dart';
import '../../../core/design/app_colors.dart';

class TeacherPendingApprovalPage extends ConsumerWidget {
  const TeacherPendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.05),
              scheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_empty,
                        size: 64,
                        color: context.c.warning,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Approval Pending',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Message
                    Text(
                      'Your teacher account is awaiting admin approval.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: context.c.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // User Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.c.textTertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 20,
                                color: context.c.textTertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.displayName ?? 'Teacher',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 20,
                                color: context.c.textTertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.email ?? '',
                                  style: TextStyle(
                                    color: context.c.textTertiary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (authState.rollNumber != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.badge,
                                  size: 20,
                                  color: context.c.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ID: ${authState.rollNumber}',
                                    style: TextStyle(
                                      color: context.c.textTertiary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.c.infoSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.c.info.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: context.c.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You will be able to access your dashboard once an admin approves your account. This usually takes 24-48 hours.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.c.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .signOut();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              // Refresh the page to check approval status
                              ref
                                  .read(authControllerProvider.notifier)
                                  .checkApprovalStatus();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check Status'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
