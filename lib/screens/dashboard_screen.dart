import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment.dart';
import '../providers/app_provider.dart';
import '../services/sms_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshPayments();
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('This will stop the payment monitor. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshPayments,
        child: CustomScrollView(
          slivers: [
            // ── Status card ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _StatusCard(provider: provider),
                    const SizedBox(height: 12),
                    if (provider.pendingCount > 0)
                      _PendingCard(provider: provider),
                  ],
                ),
              ),
            ),

            // ── Payments header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Payments',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${provider.payments.length} total',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),

            // ── Payment list ─────────────────────────────────────────
            provider.payments.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: cs.outline),
                          const SizedBox(height: 12),
                          Text('No payments yet',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('Payments will appear here as SMS arrives',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.outline)),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _PaymentTile(payment: provider.payments[i]),
                      childCount: provider.payments.length,
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Status Card ──────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final AppProvider provider;
  const _StatusCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final running = provider.serviceRunning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: running ? Colors.green : cs.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(running ? 'Service Running' : 'Service Stopped',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      running
                          ? 'Watching for Telebirr & CBE payments'
                          : 'Tap to start monitoring',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch(
              value: running,
              onChanged: (_) async {
                if (running) {
                  await provider.stopService();
                } else {
                  await SmsService.requestSmsPermissions();
                  await SmsService.requestBatteryExemption();
                  await provider.startService();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pending Card ─────────────────────────────────────────────────────────────
class _PendingCard extends StatelessWidget {
  final AppProvider provider;
  const _PendingCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${provider.pendingCount} payment${provider.pendingCount == 1 ? '' : 's'} pending sync',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
            provider.isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onErrorContainer))
                : TextButton(
                    onPressed: provider.syncNow,
                    child: Text('Sync Now',
                        style: TextStyle(color: cs.onErrorContainer)),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Payment Tile ─────────────────────────────────────────────────────────────
class _PaymentTile extends StatelessWidget {
  final Payment payment;
  const _PaymentTile({required this.payment});

  Color _statusColor(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return switch (payment.syncStatus) {
      SyncStatus.synced => Colors.green,
      SyncStatus.pending => cs.tertiary,
      SyncStatus.failed => cs.error,
    };
  }

  IconData _sourceIcon() => switch (payment.source) {
        PaymentSource.telebirr => Icons.phone_android_rounded,
        PaymentSource.cbe => Icons.account_balance_rounded,
        PaymentSource.unknown => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(_sourceIcon(), size: 18),
      ),
      title: Text('ETB ${payment.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ref: ${payment.referenceNumber}'),
          if (payment.senderPhone != null)
            Text(payment.senderPhone!,
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: payment.senderPhone != null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              payment.syncStatus.name,
              style: TextStyle(
                  fontSize: 11,
                  color: _statusColor(context),
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${payment.timestamp.day}/${payment.timestamp.month}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
