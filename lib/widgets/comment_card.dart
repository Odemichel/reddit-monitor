import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../models/reddit_comment.dart';
import '../models/item_status.dart';

class CommentCard extends StatelessWidget {
  final RedditComment comment;
  final ItemStatus status;
  final ValueChanged<ItemStatus> onStatusChanged;
  final VoidCallback onBanUser;

  const CommentCard({
    super.key,
    required this.comment,
    required this.status,
    required this.onStatusChanged,
    required this.onBanUser,
  });

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
            Uri.parse(comment.postUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post title reference
                Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        comment.postTitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Comment body
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                // Footer
                Row(
                  children: [
                    // Author
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse(comment.authorProfileUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'u/${comment.author}',
                          style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onBanUser,
                      child: Icon(
                        Icons.person_off_outlined,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Score
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 14,
                      color: const Color(0xFFFB923C).withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${comment.score}',
                      style: TextStyle(
                        color: const Color(0xFFFB923C).withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Time
                    Text(
                      timeago.format(comment.createdUtc),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    // Status
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
