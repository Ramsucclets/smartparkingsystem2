import 'package:flutter/material.dart';

class MockUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isActive;
  final String? avatarUrl;
  final int parkingSessions;

  const MockUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.lastLogin,
    required this.isActive,
    this.avatarUrl,
    required this.parkingSessions,
  });
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<MockUser> _mockUsers = [
    MockUser(
      id: 'USR001',
      name: 'John Smith',
      email: 'john.smith@example.com',
      role: 'Admin',
      createdAt: DateTime(2024, 1, 15),
      lastLogin: DateTime.now().subtract(const Duration(hours: 2)),
      isActive: true,
      parkingSessions: 156,
    ),
    MockUser(
      id: 'USR002',
      name: 'Sarah Johnson',
      email: 'sarah.j@example.com',
      role: 'User',
      createdAt: DateTime(2024, 3, 22),
      lastLogin: DateTime.now().subtract(const Duration(days: 1)),
      isActive: true,
      parkingSessions: 89,
    ),
    MockUser(
      id: 'USR003',
      name: 'Michael Chen',
      email: 'michael.chen@example.com',
      role: 'Manager',
      createdAt: DateTime(2024, 2, 8),
      lastLogin: DateTime.now().subtract(const Duration(hours: 5)),
      isActive: true,
      parkingSessions: 234,
    ),
    MockUser(
      id: 'USR004',
      name: 'Emily Davis',
      email: 'emily.d@example.com',
      role: 'User',
      createdAt: DateTime(2024, 5, 10),
      lastLogin: DateTime.now().subtract(const Duration(days: 3)),
      isActive: false,
      parkingSessions: 45,
    ),
    MockUser(
      id: 'USR005',
      name: 'Robert Wilson',
      email: 'r.wilson@example.com',
      role: 'User',
      createdAt: DateTime(2024, 4, 1),
      lastLogin: DateTime.now().subtract(const Duration(hours: 12)),
      isActive: true,
      parkingSessions: 67,
    ),
    MockUser(
      id: 'USR006',
      name: 'Lisa Anderson',
      email: 'lisa.a@example.com',
      role: 'Manager',
      createdAt: DateTime(2024, 1, 28),
      lastLogin: DateTime.now().subtract(const Duration(days: 7)),
      isActive: false,
      parkingSessions: 198,
    ),
    MockUser(
      id: 'USR007',
      name: 'David Martinez',
      email: 'david.m@example.com',
      role: 'User',
      createdAt: DateTime(2024, 6, 5),
      lastLogin: DateTime.now().subtract(const Duration(minutes: 30)),
      isActive: true,
      parkingSessions: 23,
    ),
    MockUser(
      id: 'USR008',
      name: 'Jennifer Taylor',
      email: 'j.taylor@example.com',
      role: 'Admin',
      createdAt: DateTime(2024, 2, 14),
      lastLogin: DateTime.now().subtract(const Duration(hours: 1)),
      isActive: true,
      parkingSessions: 312,
    ),
    MockUser(
      id: 'USR009',
      name: 'Chris Brown',
      email: 'chris.b@example.com',
      role: 'User',
      createdAt: DateTime(2024, 7, 20),
      lastLogin: DateTime.now().subtract(const Duration(days: 14)),
      isActive: false,
      parkingSessions: 12,
    ),
    MockUser(
      id: 'USR010',
      name: 'Amanda White',
      email: 'amanda.w@example.com',
      role: 'User',
      createdAt: DateTime(2024, 8, 3),
      lastLogin: DateTime.now().subtract(const Duration(hours: 8)),
      isActive: true,
      parkingSessions: 56,
    ),
  ];

  List<MockUser> get _filteredUsers {
    return _mockUsers.where((user) {
      final matchesSearch =
          user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              user.id.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'All' ||
          (_selectedFilter == 'Active' && user.isActive) ||
          (_selectedFilter == 'Inactive' && !user.isActive) ||
          _selectedFilter == user.role;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: isDark ? Colors.white : Colors.blueAccent,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.people_outline)),
            Tab(text: 'Statistics', icon: Icon(Icons.bar_chart)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add User',
            onPressed: () => _showAddUserDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(context, isDark),
          _buildStatisticsTab(context, isDark),
        ],
      ),
    );
  }

  Widget _buildUsersTab(BuildContext context, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    items: [
                      'All',
                      'Active',
                      'Inactive',
                      'Admin',
                      'Manager',
                      'User'
                    ]
                        .map((filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(filter),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedFilter = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filteredUsers.length} users found',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredUsers.length,
            itemBuilder: (context, index) {
              final user = _filteredUsers[index];
              return _buildUserCard(context, user, isDark, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(
      BuildContext context, MockUser user, bool isDark, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showUserDetails(context, user),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          _getRoleColor(user.role).withValues(alpha: 0.2),
                      child: Text(
                        user.name.split(' ').map((n) => n[0]).take(2).join(),
                        style: TextStyle(
                          color: _getRoleColor(user.role),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: user.isActive ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.grey[900]! : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _buildRoleChip(user.role),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last login: ${_formatLastLogin(user.lastLogin)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.local_parking,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${user.parkingSessions} sessions',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  onSelected: (value) =>
                      _handleUserAction(context, user, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 20),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit User'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: user.isActive ? 'deactivate' : 'activate',
                      child: Row(
                        children: [
                          Icon(
                            user.isActive ? Icons.block : Icons.check_circle,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(user.isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin':
        return Colors.purple;
      case 'Manager':
        return Colors.blue;
      case 'User':
      default:
        return Colors.teal;
    }
  }

  String _formatLastLogin(DateTime lastLogin) {
    final now = DateTime.now();
    final difference = now.difference(lastLogin);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastLogin.day}/${lastLogin.month}/${lastLogin.year}';
    }
  }

  Widget _buildStatisticsTab(BuildContext context, bool isDark) {
    final totalUsers = _mockUsers.length;
    final activeUsers = _mockUsers.where((u) => u.isActive).length;
    final adminCount = _mockUsers.where((u) => u.role == 'Admin').length;
    final managerCount = _mockUsers.where((u) => u.role == 'Manager').length;
    final userCount = _mockUsers.where((u) => u.role == 'User').length;
    final totalSessions =
        _mockUsers.fold<int>(0, (sum, u) => sum + u.parkingSessions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                context,
                'Total Users',
                totalUsers.toString(),
                Icons.people,
                Colors.blueAccent,
                isDark,
              ),
              _buildStatCard(
                context,
                'Active Users',
                activeUsers.toString(),
                Icons.person_outline,
                Colors.green,
                isDark,
              ),
              _buildStatCard(
                context,
                'Total Sessions',
                totalSessions.toString(),
                Icons.local_parking,
                Colors.orange,
                isDark,
              ),
              _buildStatCard(
                context,
                'Avg Sessions/User',
                (totalSessions / totalUsers).toStringAsFixed(1),
                Icons.analytics,
                Colors.purple,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Role Distribution',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildRoleDistribution(
            context,
            isDark,
            adminCount,
            managerCount,
            userCount,
            totalUsers,
          ),
          const SizedBox(height: 32),
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildRecentActivity(context, isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: color, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDistribution(
    BuildContext context,
    bool isDark,
    int adminCount,
    int managerCount,
    int userCount,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildRoleBar('Admins', adminCount, total, Colors.purple, isDark),
          const SizedBox(height: 16),
          _buildRoleBar('Managers', managerCount, total, Colors.blue, isDark),
          const SizedBox(height: 16),
          _buildRoleBar('Users', userCount, total, Colors.teal, isDark),
        ],
      ),
    );
  }

  Widget _buildRoleBar(
    String role,
    int count,
    int total,
    Color color,
    bool isDark,
  ) {
    final percentage = (count / total * 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              role,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              '$count (${percentage.toStringAsFixed(0)}%)',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: count / total,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDark) {
    final activities = [
      {
        'user': 'John Smith',
        'action': 'logged in',
        'time': '2 hours ago',
        'icon': Icons.login
      },
      {
        'user': 'Sarah Johnson',
        'action': 'updated profile',
        'time': '5 hours ago',
        'icon': Icons.edit
      },
      {
        'user': 'Michael Chen',
        'action': 'started parking session',
        'time': '6 hours ago',
        'icon': Icons.local_parking
      },
      {
        'user': 'Emily Davis',
        'action': 'account deactivated',
        'time': '3 days ago',
        'icon': Icons.block
      },
      {
        'user': 'David Martinez',
        'action': 'registered',
        'time': '1 week ago',
        'icon': Icons.person_add
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
              child: Icon(
                activity['icon'] as IconData,
                color: Colors.blueAccent,
                size: 20,
              ),
            ),
            title: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: activity['user'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' ${activity['action']}'),
                ],
              ),
            ),
            trailing: Text(
              activity['time'] as String,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUserDetails(BuildContext context, MockUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.black.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          _getRoleColor(user.role).withValues(alpha: 0.2),
                      child: Text(
                        user.name.split(' ').map((n) => n[0]).take(2).join(),
                        style: TextStyle(
                          color: _getRoleColor(user.role),
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildRoleChip(user.role),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: user.isActive
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  user.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: user.isActive
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildDetailRow(Icons.badge, 'User ID', user.id, isDark),
                _buildDetailRow(Icons.email, 'Email', user.email, isDark),
                _buildDetailRow(
                  Icons.calendar_today,
                  'Member Since',
                  '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                  isDark,
                ),
                _buildDetailRow(
                  Icons.access_time,
                  'Last Login',
                  _formatLastLogin(user.lastLogin),
                  isDark,
                ),
                _buildDetailRow(
                  Icons.local_parking,
                  'Total Parking Sessions',
                  user.parkingSessions.toString(),
                  isDark,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSnackBar(
                              context, 'Edit functionality coming soon');
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSnackBar(
                            context,
                            user.isActive
                                ? 'User deactivated (demo)'
                                : 'User activated (demo)',
                          );
                        },
                        icon: Icon(
                            user.isActive ? Icons.block : Icons.check_circle),
                        label: Text(user.isActive ? 'Deactivate' : 'Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              user.isActive ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleUserAction(BuildContext context, MockUser user, String action) {
    switch (action) {
      case 'view':
        _showUserDetails(context, user);
        break;
      case 'edit':
        _showSnackBar(context, 'Edit ${user.name} - Coming soon');
        break;
      case 'activate':
      case 'deactivate':
        _showSnackBar(
          context,
          '${user.name} ${action}d (demo)',
        );
        break;
      case 'delete':
        _showDeleteConfirmation(context, user);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context, MockUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
          'Are you sure you want to delete ${user.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(context, '${user.name} deleted (demo)');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: const Text(
          'This is a demo screen. In production, this would open a form '
          'to create a new user in the Cognito user pool.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
