import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../config.dart';
import '../models/item_status.dart';
import '../models/reddit_thread.dart';
import '../models/reddit_comment.dart';
import '../services/local_storage_service.dart';
import '../services/reddit_service.dart';
import '../widgets/thread_card.dart';
import '../widgets/comment_card.dart';

class DashboardScreen extends StatefulWidget {
  final LocalStorageService storage;

  const DashboardScreen({super.key, required this.storage});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _redditService = RedditService();
  late TabController _tabController;

  List<RedditThread> _threads = [];
  List<RedditComment> _comments = [];
  Map<String, ItemStatus> _statuses = {};
  bool _loadingThreads = false;
  bool _loadingComments = false;
  DateTime? _lastUpdated;
  DateTime? _lastScanDate;
  int _newPostsFoundThisScan = 0;
  Timer? _autoRefreshTimer;
  StreamSubscription<List<RedditThread>>? _threadsSub;

  // Filters
  String? _selectedSubreddit;
  ItemStatus? _selectedThreadStatus;
  ItemStatus? _selectedCommentStatus;
  final bool _hideIgnored = true;
  Set<String> _bannedUsers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCache();
    _refresh();
    _autoRefreshTimer = Timer.periodic(autoRefreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _threadsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _loadCache() {
    _threads = widget.storage.loadCachedThreads();
    _comments = widget.storage.loadCachedComments();
    _statuses = widget.storage.loadStatuses();
    _bannedUsers = widget.storage.loadBannedUsers();
    _lastScanDate = widget.storage.loadLastScanDate();
  }

  ItemStatus _statusFor(String id) => _statuses[id] ?? ItemStatus.nouveau;

  void _setStatus(String id, ItemStatus status) {
    setState(() => _statuses[id] = status);
    widget.storage.saveStatuses(_statuses);
  }

  bool _isUserBanned(String author) =>
      author.toLowerCase() == redditUsername.toLowerCase() ||
      _bannedUsers.contains(author.toLowerCase());

  void _banUser(String author) {
    setState(() => _bannedUsers.add(author.toLowerCase()));
    widget.storage.saveBannedUsers(_bannedUsers);
  }

  void _unbanUser(String author) {
    setState(() => _bannedUsers.remove(author.toLowerCase()));
    widget.storage.saveBannedUsers(_bannedUsers);
  }

  Future<void> _refresh() async {
    _threadsSub?.cancel();
    final scanStart = DateTime.now();
    final previousCount = _threads.length;

    setState(() {
      _loadingThreads = true;
      _loadingComments = true;
      _newPostsFoundThisScan = 0;
    });

    // Fetch comments FIRST (few requests, avoid getting rate-limited)
    try {
      final newComments = await _redditService.fetchMyPostComments();
      if (mounted) {
        setState(() {
          _mergeComments(newComments);
          _loadingComments = false;
          _lastUpdated = DateTime.now();
        });
        widget.storage.saveCachedComments(_comments);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }

    // Then stream threads progressively (many requests, throttled)
    _threadsSub = _redditService
        .streamInterestingThreads(lastScanDate: _lastScanDate)
        .listen(
          (newThreads) {
            if (!mounted) return;
            setState(() {
              _mergeThreads(newThreads);
              _newPostsFoundThisScan = _threads.length - previousCount;
              _lastUpdated = DateTime.now();
            });
            widget.storage.saveCachedThreads(_threads);
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _loadingThreads = false;
                _lastScanDate = scanStart;
              });
              widget.storage.saveLastScanDate(scanStart);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _loadingThreads = false);
          },
        );
  }

  void _mergeThreads(List<RedditThread> incoming) {
    final map = {for (final t in _threads) t.id: t};
    for (final t in incoming) {
      map[t.id] = t; // update existing or add new
    }
    _threads = map.values.toList()
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
  }

  void _mergeComments(List<RedditComment> incoming) {
    final map = {for (final c in _comments) c.id: c};
    for (final c in incoming) {
      map[c.id] = c;
    }
    _comments = map.values.toList()
      ..sort((a, b) => b.createdUtc.compareTo(a.createdUtc));
  }

  // --- Filtered lists ---

  List<RedditThread> get _filteredThreads {
    return _threads.where((t) {
      if (_isUserBanned(t.author)) return false;
      if (_hideIgnored && _statusFor(t.id) == ItemStatus.ignore) return false;
      if (_selectedSubreddit != null && t.subreddit != _selectedSubreddit) {
        return false;
      }
      if (_selectedThreadStatus != null &&
          _statusFor(t.id) != _selectedThreadStatus) {
        return false;
      }
      return true;
    }).toList();
  }

  List<RedditComment> get _filteredComments {
    return _comments.where((c) {
      if (_isUserBanned(c.author)) return false;
      if (_hideIgnored && _statusFor(c.id) == ItemStatus.ignore) return false;
      if (_selectedCommentStatus != null &&
          _statusFor(c.id) != _selectedCommentStatus) {
        return false;
      }
      return true;
    }).toList();
  }

  Set<String> get _availableSubreddits =>
      _threads.map((t) => t.subreddit).toSet();

  // --- Count badges ---

  int get _newThreadsCount => _threads
      .where(
        (t) =>
            !_isUserBanned(t.author) && _statusFor(t.id) == ItemStatus.nouveau,
      )
      .length;

  int get _newCommentsCount => _comments
      .where(
        (c) =>
            !_isUserBanned(c.author) && _statusFor(c.id) == ItemStatus.nouveau,
      )
      .length;

  void _showBannedUsersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Utilisateurs masqués',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: SizedBox(
            width: 300,
            child: _bannedUsers.isEmpty
                ? const Text(
                    'Aucun utilisateur masqué',
                    style: TextStyle(color: Color(0xFF64748B)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _bannedUsers.toList().map((user) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'u/$user',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.restore_rounded,
                            color: Color(0xFF60A5FA),
                            size: 20,
                          ),
                          onPressed: () {
                            _unbanUser(user);
                            setDialogState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.radar, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(
              'AeroX Monitor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_lastUpdated != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Scan ${timeago.format(_lastUpdated!)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    if (_newPostsFoundThisScan > 0 || _loadingThreads)
                      Text(
                        _loadingThreads
                            ? '${_newPostsFoundThisScan} nouveaux...'
                            : '$_newPostsFoundThisScan nouveaux posts',
                        style: TextStyle(
                          color: _newPostsFoundThisScan > 0
                              ? const Color(0xFF34D399)
                              : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          _buildRefreshButton(),
          if (_bannedUsers.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.person_off_outlined,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
              tooltip: 'Utilisateurs masqués',
              onPressed: _showBannedUsersDialog,
            ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF60A5FA),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text('Threads'),
                  if (_newThreadsCount > 0) ...[
                    const SizedBox(width: 8),
                    _CountBadge(count: _newThreadsCount),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text('Mes commentaires'),
                  if (_newCommentsCount > 0) ...[
                    const SizedBox(width: 8),
                    _CountBadge(count: _newCommentsCount),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildThreadsTab(), _buildCommentsTab()],
      ),
    );
  }

  Widget _buildRefreshButton() {
    final isLoading = _loadingThreads || _loadingComments;
    return IconButton(
      onPressed: isLoading ? null : _refresh,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF60A5FA),
              ),
            )
          : const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
    );
  }

  // --- Threads tab ---

  Widget _buildThreadsTab() {
    return Column(
      children: [
        // Subreddit filter chips
        _buildSubredditChips(),
        // Status filter
        _buildStatusFilter(
          selected: _selectedThreadStatus,
          onSelected: (s) => setState(() {
            _selectedThreadStatus = _selectedThreadStatus == s ? null : s;
          }),
        ),
        // List
        Expanded(child: _buildThreadsList()),
      ],
    );
  }

  Widget _buildSubredditChips() {
    final subs = _availableSubreddits.toList()..sort();
    if (subs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      padding: const EdgeInsets.only(top: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'Tous',
            selected: _selectedSubreddit == null,
            onTap: () => setState(() => _selectedSubreddit = null),
          ),
          ...subs.map(
            (sub) => _FilterChip(
              label: 'r/$sub',
              selected: _selectedSubreddit == sub,
              onTap: () => setState(() {
                _selectedSubreddit = _selectedSubreddit == sub ? null : sub;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter({
    required ItemStatus? selected,
    required ValueChanged<ItemStatus?> onSelected,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(top: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: ItemStatus.values
            .where((s) => s != ItemStatus.ignore)
            .map(
              (s) => _FilterChip(
                label: s.label,
                icon: s.icon,
                color: s.color,
                selected: selected == s,
                onTap: () => onSelected(s),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildThreadsList() {
    final filtered = _filteredThreads;

    if (_loadingThreads && _threads.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun thread trouvé',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: filtered.length + (_loadingThreads ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == filtered.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF60A5FA),
                ),
              ),
            ),
          );
        }
        final thread = filtered[i];
        return ThreadCard(
          thread: thread,
          status: _statusFor(thread.id),
          onStatusChanged: (s) => _setStatus(thread.id, s),
          onBanUser: () => _banUser(thread.author),
        );
      },
    );
  }

  // --- Comments tab ---

  Widget _buildCommentsTab() {
    return Column(
      children: [
        _buildStatusFilter(
          selected: _selectedCommentStatus,
          onSelected: (s) => setState(() {
            _selectedCommentStatus = _selectedCommentStatus == s ? null : s;
          }),
        ),
        Expanded(child: _buildCommentsList()),
      ],
    );
  }

  Widget _buildCommentsList() {
    final filtered = _filteredComments;

    if (_loadingComments && _comments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun commentaire trouvé',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final comment = filtered[i];
        return CommentCard(
          comment: comment,
          status: _statusFor(comment.id),
          onStatusChanged: (s) => _setStatus(comment.id, s),
          onBanUser: () => _banUser(comment.author),
        );
      },
    );
  }
}

// --- Shared widgets ---

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF60A5FA);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? chipColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? chipColor.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? chipColor : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? chipColor : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
