import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen displayed when the required `--dart-define` parameters are missing.
class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const exampleCommand =
        'flutter run \\\n'
        '  --dart-define=SUPABASE_URL=https://xyzcompany.supabase.co \\\n'
        '  --dart-define=SUPABASE_PUBLISHABLE_KEY=eyJhbGciOi...';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.key_rounded,
                  size: 64,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Supabase Credentials Needed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The application requires SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
                  'passed at runtime via --dart-define.\n\n'
                  'No credentials were hardcoded into the source code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Launch Command',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: Color(0xFF38BDF8),
                            ),
                            tooltip: 'Copy command template',
                            onPressed: () {
                              Clipboard.setData(
                                const ClipboardData(text: exampleCommand),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Command template copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const SelectableText(
                        exampleCommand,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF38BDF8),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D).withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFFFCA5A5), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SECURITY NOTE: Never use the secret key or service_role key.',
                          style: TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
