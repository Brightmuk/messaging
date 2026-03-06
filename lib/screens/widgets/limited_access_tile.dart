import 'package:flutter/material.dart';


class LimitedAccessTile extends StatefulWidget {
  final VoidCallback onRequest;
  const LimitedAccessTile({super.key, required this.onRequest});

  @override
  State<LimitedAccessTile> createState() => _LimitedAccessTileState();
}

class _LimitedAccessTileState extends State<LimitedAccessTile> {
  bool hide = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if(hide){
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child:
                    const Icon(Icons.security, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Limited Privacy Mode",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(onPressed: (){
                setState(() {
                  hide = true;
                });
              }, icon: const Icon(Icons.clear, size: 15,))
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "M-Ficha is currently only showing financial messages. Set as default app to manage other messages on your device",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => widget.onRequest(),
              child: const Text("Set as Default App"),
            ),
          ),
        ],
      ),
    );
  }
}