import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../models/reddit_thread.dart';
import '../models/item_status.dart';

class ThreadCard extends StatelessWidget {
  final RedditThread thread;
  final ItemStatus status;
  final ValueChanged<ItemStatus> onStatusChanged;

  const ThreadCard({
    super.key,
    required this.thread,
    required this.status,
    required this.onStatusChanged,
  });

  Color _relevanceColor(int score) {
    if (score >= 8) return const Color(0xFF34D399);
    if (score >= 5) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  @override
  Widget build(BuildContext context) {
    final isIgnored = status == ItemStatus.ignore;

    return Opacity(
      opacity: isIgnored ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: status == ItemStatus.nouveau
                ? const Color(0xFF60A5FA).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => launchUrl(
            Uri.parse(thread.redditUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Relevance score
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _relevanceColor(
                          thread.relevanceScore,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${thread.relevanceScore}',
                        style: TextStyle(
                          color: _relevanceColor(thread.relevanceScore),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Subreddit
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'r/${thread.subreddit}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Time
                    Text(
                      timeago.format(thread.createdUtc),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  thread.title,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                // Footer row
                Row(
                  children: [
                    // Upvotes
                    _StatChip(
                      icon: Icons.arrow_upward_rounded,
                      value: '${thread.score}',
                      color: const Color(0xFFFB923C),
                    ),
                    const SizedBox(width: 12),
                    // Comments
                    _StatChip(
                      icon: Icons.chat_bubble_outline_rounded,
                      value: '${thread.numComments}',
                      color: const Color(0xFF60A5FA),
                    ),
                    const Spacer(),
                    // Status selector
                    _StatusButton(status: status, onChanged: onStatusChanged),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final ItemStatus status;
  final ValueChanged<ItemStatus> onChanged;

  const _StatusButton({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ItemStatus>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF2A2A3E),
      offset: const Offset(0, -200),
      itemBuilder: (_) => ItemStatus.values.map((s) {
        return PopupMenuItem(
          value: s,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, size: 18, color: s.color),
              const SizedBox(width: 10),
              Text(s.label, style: TextStyle(color: s.color, fontSize: 14)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 14, color: status.color),
            const SizedBox(width: 5),
            Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
