import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/sms_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _domainCtrl;
  late TextEditingController _senderCtrl;
  List<String> _senders = [];

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _domainCtrl = TextEditingController(text: provider.domain);
    _senderCtrl = TextEditingController();
    _senders = List.from(provider.senderFilters);
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  void _addSender() {
    final val = _senderCtrl.text.trim();
    if (val.isEmpty || _senders.contains(val)) return;
    setState(() => _senders.add(val));
    _senderCtrl.clear();
  }

  void _removeSender(String s) => setState(() => _senders.remove(s));

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    await provider.saveDomain(_domainCtrl.text.trim());
    await provider.saveSenderFilters(_senders);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── API Endpoint ──────────────────────────────────────────────
          _SectionHeader('API Configuration'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _domainCtrl,
            decoration: const InputDecoration(
              labelText: 'API Domain',
              hintText: 'https://myapp.com',
              helperText: 'The app will POST to {domain}/api/register_payment',
              prefixIcon: Icon(Icons.link_rounded),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 24),

          // ── SMS Sender Filters ────────────────────────────────────────
          _SectionHeader('SMS Sender Filters'),
          const SizedBox(height: 4),
          Text(
            'Only SMS from these senders will be processed. Default: 127, CBE.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _senders
                .map((s) => Chip(
                      label: Text(s),
                      onDeleted: () => _removeSender(s),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _senderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Add sender ID',
                    hintText: 'e.g. 127',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addSender(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addSender, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 28),

          // ── Battery Optimization ──────────────────────────────────────
          _SectionHeader('Battery Optimization'),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('Exempt from Battery Optimization'),
              subtitle: const Text(
                  'Required on Xiaomi, Samsung, Oppo and similar phones to keep the service alive in background.'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () async {
                await SmsService.requestBatteryExemption();
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Permissions ───────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Request SMS Permissions'),
              subtitle: const Text(
                  'Grant READ_SMS and RECEIVE_SMS if not already allowed.'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () async {
                final granted = await SmsService.requestSmsPermissions();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(granted
                      ? 'SMS permissions granted ✅'
                      : 'Permissions denied — please grant in App Settings'),
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
