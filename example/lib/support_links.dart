import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportLinks extends StatelessWidget {
  const SupportLinks({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Support open source',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      const Text(
        'Contributions help sustain development. Gift and coffee are a way to show more love.',
      ),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _link(context, 'Supported by', 'https://aflare.space'),
          _link(context, 'Buy a coffee · example', ''),
          _link(
            context,
            'GitHub',
            'https://github.com/itskenzylimon/quickeydb',
          ),
          _link(context, 'Blog & Articles', 'https://medium.com/@itskenzylimon'),
          _link(
            context,
            'Built reactively by QuickeyDB ↗',
            'https://pub.dev/packages/quickeydb',
          ),
        ],
      ),
    ],
  );
  Widget _link(BuildContext context, String label, String url) => TextButton(
    onPressed:
        url.isEmpty
            ? null
            : () async {
              final uri = Uri.tryParse(url);
              final valid =
                  uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
              final opened =
                  valid &&
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open this link. Check the configured HTTPS address.',
                    ),
                  ),
                );
              }
            },
    child: Text(label),
  );
}
