import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/clickable_cursor.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

class EmployeeManagerScreen extends StatefulWidget {
  const EmployeeManagerScreen({super.key});

  @override
  State<EmployeeManagerScreen> createState() => _EmployeeManagerScreenState();
}

class _EmployeeManagerScreenState extends State<EmployeeManagerScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRole = 'cashier';
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'cashier':
      default:
        return CafeColors.flame;
    }
  }

  Color _roleBgColor(String role) {
    switch (role.toLowerCase()) {
      case 'cashier':
      default:
        return CafeColors.creme;
    }
  }

  LinearGradient _avatarGradient(String name) {
    final gradients = [
      const LinearGradient(colors: [Color(0xFFFF4D1C), Color(0xFFFF8C42)]),
      const LinearGradient(colors: [Color(0xFFFFA724), Color(0xFFFFCC70)]),
      const LinearGradient(colors: [Color(0xFF2D6A4F), Color(0xFF52B788)]),
      const LinearGradient(colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)]),
      const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFFFF6EC7)]),
    ];

    if (name.isEmpty) return gradients[0];

    return gradients[name.codeUnitAt(0) % gradients.length];
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 14, color: CafeColors.charcoal),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: CafeColors.flame.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: CafeColors.flame, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CafeColors.flame, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _selectedRole = 'cashier';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> createEmployee() async {
              final name = _nameController.text.trim();
              final email = _emailController.text.trim();
              final password = _passwordController.text.trim();

              if (name.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setDialogState(() => _isCreating = true);

              final auth = Provider.of<AuthProvider>(context, listen: false);
              final result = await auth.createEmployee(
                email: email,
                password: password,
                name: name,
                role: _selectedRole,
              );

              setDialogState(() => _isCreating = false);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!context.mounted) return;

              final success = result['success'] == true;
              final errorMsg = result['error']?.toString();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Employee created successfully'
                        : errorMsg ?? 'Failed to create employee',
                  ),
                  backgroundColor: success ? CafeColors.olive : Colors.red,
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 460,
                  maxHeight: MediaQuery.of(context).size.height * 0.86,
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 380 ? 16 : 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: CafeColors.headerGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_add_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Add Employee',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: CafeColors.charcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _styledField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _styledField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _styledField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'Role',
                            labelStyle: TextStyle(
                                color: CafeColors.flame.withOpacity(0.8)),
                            prefixIcon: const Icon(Icons.badge_outlined,
                                color: CafeColors.flame, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: CafeColors.flame.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: CafeColors.flame, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'cashier', child: Text('Cashier')),
                          ],
                          onChanged: (value) => setDialogState(
                              () => _selectedRole = value ?? 'cashier'),
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 340;
                            final cancelButton = OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                    color: CafeColors.flame.withOpacity(0.4)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cancel',
                                  style: TextStyle(color: CafeColors.flame)),
                            );
                            final createButton = DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: CafeColors.headerGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton(
                                onPressed: _isCreating ? null : createEmployee,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isCreating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Create',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                              ),
                            );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  cancelButton,
                                  const SizedBox(height: 10),
                                  createButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: cancelButton),
                                const SizedBox(width: 12),
                                Expanded(child: createButton),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String userId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Delete Employee',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CafeColors.charcoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "$name"? This action cannot be undone.',
                style: TextStyle(
                    fontSize: 14,
                    color: CafeColors.charcoal.withOpacity(0.7),
                    height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: CafeColors.flame.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: CafeColors.flame)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        final success = await auth.deleteEmployee(userId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Employee deleted'
                                : 'Failed to delete employee'),
                            backgroundColor:
                                success ? CafeColors.olive : Colors.red,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditRoleDialog(
      BuildContext context, String userId, String currentRole, String name) {
    String selectedRole = currentRole;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;
                    final cancelButton = OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: CafeColors.flame.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: CafeColors.flame)),
                    );
                    final updateButton = DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: CafeColors.headerGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final auth =
                              Provider.of<AuthProvider>(context, listen: false);
                          final success =
                              await auth.updateUserRole(userId, selectedRole);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Role updated successfully'
                                  : 'Failed to update role'),
                              backgroundColor:
                                  success ? CafeColors.olive : Colors.red,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Update',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    );

                    return Padding(
                      padding: EdgeInsets.all(compact ? 18 : 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: CafeColors.headerGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.badge_outlined,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Change Role',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: CafeColors.charcoal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: CafeColors.charcoal.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              labelStyle: TextStyle(
                                  color: CafeColors.flame.withOpacity(0.8)),
                              prefixIcon: const Icon(Icons.badge_outlined,
                                  color: CafeColors.flame, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: CafeColors.flame.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: CafeColors.flame, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'cashier', child: Text('Cashier')),
                            ],
                            onChanged: (value) => setDialogState(
                                () => selectedRole = value ?? 'cashier'),
                          ),
                          const SizedBox(height: 24),
                          if (compact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                cancelButton,
                                const SizedBox(height: 10),
                                updateButton,
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(child: cancelButton),
                                const SizedBox(width: 12),
                                Expanded(child: updateButton),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (!auth.isAdmin) {
          return Scaffold(
            backgroundColor: NovaColors.bgTertiary,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: CafeColors.headerGradient,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x33534AB7),
                        blurRadius: 12,
                        offset: Offset(0, 4))
                  ],
                ),
                child: SafeArea(
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    title: const Text('Access Denied',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEB), shape: BoxShape.circle),
                    child: const Icon(Icons.admin_panel_settings,
                        size: 52, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  const Text('Admin Only',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: CafeColors.charcoal)),
                  const SizedBox(height: 8),
                  Text('You do not have permission to view this page',
                      style: TextStyle(
                          color: CafeColors.charcoal.withOpacity(0.5),
                          fontSize: 14)),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: CafeColors.headerGradient,
                        borderRadius: BorderRadius.circular(14)),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Go Back',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.name ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoUrl;

        final isDesktop = AppNavigationShell.isDesktop(context);

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: null,
          bottomNavigationBar:
              !isDesktop ? const AppMobileBottomNavBar(currentIndex: 1) : null,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              decoration: const BoxDecoration(
                gradient: CafeColors.headerGradient,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x33534AB7),
                      blurRadius: 12,
                      offset: Offset(0, 4))
                ],
              ),
              child: SafeArea(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Row(
                    children: [
                      Icon(Icons.badge_rounded,
                          color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Employee Manager',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    if (!isDesktop)
                      IconButton(
                        tooltip: 'Logout',
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.white70),
                        onPressed: () async {
                          final isMobile =
                              MediaQuery.sizeOf(context).width < 600;
                          bool confirm = true;
                          if (!isMobile) {
                            confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('Logout'),
                                    content: const Text(
                                        'Are you sure you want to logout?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, true),
                                        style: TextButton.styleFrom(
                                            foregroundColor: Colors.red),
                                        child: const Text('Logout'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          }
                          if (confirm && context.mounted) {
                            await Provider.of<AuthProvider>(context,
                                    listen: false)
                                .logout();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (route) => false,
                              );
                            }
                          }
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppDrawerAvatarButton(
                        photoUrl: photoUrl,
                        userName: userName,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/employees',
            child: ResponsiveCenter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: NovaColors.bgPrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: NovaColors.borderTertiary,
                                width: 0.5,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              cursorColor: NovaColors.violet,
                              onChanged: (v) => setState(
                                  () => _searchQuery = v.toLowerCase()),
                              style: const TextStyle(
                                  fontSize: 14, color: NovaColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Search employees...',
                                hintStyle: const TextStyle(
                                    color: NovaColors.textTertiary,
                                    fontSize: 14),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: NovaColors.textSecondary, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            color: NovaColors.textTertiary,
                                            size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                filled: true,
                                fillColor: NovaColors.bgPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: CafeColors.headerGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: CafeColors.flame.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            tooltip: 'Add Employee',
                            onPressed: () => _showCreateDialog(context),
                            icon: const Icon(Icons.person_add_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: auth.getEmployees(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: NovaColors.violet),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }

                        final employees = snapshot.data ?? [];
                        final filtered = employees.where((e) {
                          final name =
                              e['name']?.toString().toLowerCase() ?? '';
                          final email =
                              e['email']?.toString().toLowerCase() ?? '';
                          final role =
                              e['role']?.toString().toLowerCase() ?? '';
                          return _searchQuery.isEmpty ||
                              name.contains(_searchQuery) ||
                              email.contains(_searchQuery) ||
                              role.contains(_searchQuery);
                        }).toList();

                        if (employees.isEmpty) {
                          return _emptyStateView(
                            icon: Icons.people_outline_rounded,
                            title: 'No employees yet',
                            subtitle: 'Tap + to add your first employee',
                          );
                        }
                        if (filtered.isEmpty) {
                          return _emptyStateView(
                            icon: Icons.search_off_rounded,
                            title: 'No results found',
                            subtitle: 'No employees match "$_searchQuery"',
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = ResponsiveLayout.cardColumns(
                                constraints.maxWidth);

                            Widget buildEmployeeCard(int index) {
                              final employee = filtered[index];

                              final rawName =
                                  (employee['name']?.toString() ?? '').trim();
                              final name =
                                  rawName.isEmpty ? 'Unknown' : rawName;

                              final email = employee['email']?.toString() ?? '';
                              final role =
                                  employee['role']?.toString() ?? 'cashier';
                              final userId = employee['id']?.toString() ?? '';

                              return _EmployeeCard(
                                name: name,
                                email: email,
                                role: role,
                                avatarGradient: _avatarGradient(name),
                                roleColor: _roleColor(role),
                                roleBgColor: _roleBgColor(role),
                                onEdit: () => _showEditRoleDialog(
                                  context,
                                  userId,
                                  role,
                                  name,
                                ),
                                onDelete: () =>
                                    _confirmDelete(context, userId, name),
                              );
                            }

                            if (columns == 1) {
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    buildEmployeeCard(index),
                              );
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 136,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  buildEmployeeCard(index),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyStateView({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: CafeColors.creme,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: CafeColors.flame),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CafeColors.charcoal)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13, color: CafeColors.charcoal.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final LinearGradient avatarGradient;
  final Color roleColor;
  final Color roleBgColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmployeeCard({
    required this.name,
    required this.email,
    required this.role,
    required this.avatarGradient,
    required this.roleColor,
    required this.roleBgColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: CafeColors.flame.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: avatarGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CafeColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(
                        fontSize: 12,
                        color: CafeColors.charcoal.withOpacity(0.5)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: roleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _ActionIconButton(
                  icon: Icons.edit_rounded,
                  color: CafeColors.flame,
                  bgColor: CafeColors.creme,
                  tooltip: 'Change Role',
                  onTap: onEdit,
                ),
                const SizedBox(height: 8),
                _ActionIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red,
                  bgColor: const Color(0xFFFFEBEB),
                  tooltip: 'Delete',
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClickableCursor(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }
}
