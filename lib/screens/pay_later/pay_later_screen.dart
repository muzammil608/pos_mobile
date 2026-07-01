import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/utils/app_notice.dart';
import '../../models/pay_later_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pay_later_service.dart';
import '../../services/pocketbase/repair_service.dart';
import '../../widgets/app_navigation.dart';

class PayLaterScreen extends StatefulWidget {
  const PayLaterScreen({super.key});

  @override
  State<PayLaterScreen> createState() => _PayLaterScreenState();
}

class _PayLaterScreenState extends State<PayLaterScreen> {
  final _noticeKey = GlobalKey<AppNoticeHostState>();
  final _searchController = TextEditingController();
  PayLaterService? _service;
  late Future<List<PayLaterPerson>> _future;
  String _query = '';
  String _khataType = KhataType.accessory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (_service == null) {
      _service = PayLaterService(auth.ownerId);
      _future = _loadPeopleAndSyncRepairs();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted || _service == null) return;
    final next = _loadPeopleAndSyncRepairs();
    setState(() {
      _future = next;
    });
  }

  Future<List<PayLaterPerson>> _loadPeopleAndSyncRepairs() async {
    final ownerId = context.read<AuthProvider>().ownerId;
    final people = await _service!.getPeople();
    try {
      final repairService = RepairService(ownerId);
      final repairs = await repairService.getRepairsList();

      for (final person in people.where(
        (person) => person.khataType == KhataType.repair,
      )) {
        final references = person.entries
            .where((entry) =>
                !entry.isPayment &&
                (entry.orderNumber?.startsWith('REPAIR-') ?? false))
            .map((entry) => entry.orderNumber!)
            .toSet();
        final linked = repairs
            .where((repair) => references.contains('REPAIR-${repair.jobId}'))
            .where((repair) => repair.remainingBalance > 0.01)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final repairBalance = linked.fold<double>(
          0,
          (sum, repair) => sum + repair.remainingBalance,
        );
        var paymentToApply =
            repairBalance - person.balance.clamp(0, double.infinity);
        if (paymentToApply <= 0.01) continue;

        for (final repair in linked) {
          if (paymentToApply <= 0.01) break;
          final applied = paymentToApply.clamp(0, repair.remainingBalance);
          await repairService.updateRepair(
            repair.id,
            values: {'advancePayment': repair.advancePayment + applied},
          );
          paymentToApply -= applied;
        }
      }
    } catch (_) {
      // Khata remains usable offline; repair sync retries on the next refresh.
    }
    return people;
  }

  String _money(double value) => 'Rs ${value.toStringAsFixed(0)}';

  List<PayLaterPerson> _filtered(List<PayLaterPerson> people) {
    final q = _query.trim().toLowerCase();
    return people.where((person) {
      if (person.khataType != _khataType) return false;
      if (q.isEmpty) return true;
      return person.name.toLowerCase().contains(q) ||
          person.phone.toLowerCase().contains(q) ||
          person.address.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openPersonForm({PayLaterPerson? person}) async {
    if (_service == null) return;
    final isNewCashCustomer = person == null && _khataType == KhataType.cash;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PersonFormDialog(
        person: person,
        showInitialCashAmount: isNewCashCustomer,
        onSave: (name, phone, address, note, dueDate, initialAmount) async {
          final savedPerson = await _service!.upsertPerson(
            id: person?.id,
            name: name,
            phone: phone,
            khataType: person?.khataType ?? _khataType,
            address: address,
            note: note,
            dueDate: dueDate,
          );
          if (isNewCashCustomer && initialAmount > 0) {
            await _service!.addEntry(
              personId: savedPerson.id,
              type: 'debit',
              amount: initialAmount,
              note: note.trim().isEmpty ? 'Cash udhaar given' : note,
            );
          }
        },
      ),
    );
    if (saved == true) {
      _noticeKey.currentState?.show('Customer saved.');
      _refresh();
    }
  }

  Future<void> _openEntryForm(PayLaterPerson person, String type) async {
    if (_service == null) return;
    final isPayment = type == 'payment';
    final isCashKhata = person.khataType == KhataType.cash;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EntryFormDialog(
        title: isPayment
            ? (isCashKhata ? 'Cash Returned' : 'Receive Payment')
            : (isCashKhata ? 'Give Cash Udhaar' : 'Add Credit Sale'),
        actionLabel: isPayment
            ? (isCashKhata ? 'Cash Returned' : 'Received')
            : (isCashKhata ? 'Give Cash' : 'Add to Khata'),
        helperText: isPayment
            ? (isCashKhata
                ? 'Record cash returned to the shop owner.'
                : 'Use this when the customer gives you money.')
            : (isCashKhata
                ? 'Personal cash udhaar only. This does not affect app profit.'
                : 'Use this when the customer takes items and will pay later.'),
        icon: isPayment
            ? Icons.payments_rounded
            : (isCashKhata
                ? Icons.currency_rupee_rounded
                : Icons.add_card_rounded),
        color: isPayment ? NovaColors.teal : NovaColors.amber,
        maxAmount: isPayment && person.balance > 0 ? person.balance : null,
        onSave: (amount, note) async {
          return _service!.addEntry(
            personId: person.id,
            type: type,
            amount: amount,
            note: note,
          );
        },
      ),
    );
    if (saved == true) {
      _noticeKey.currentState?.show(
        isPayment ? 'Payment received.' : 'Credit sale added.',
      );
      _refresh();
    }
  }

  Future<void> _deletePerson(PayLaterPerson person) async {
    if (_service == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _KhataDialogFrame(
        title: 'Delete Customer?',
        icon: Icons.delete_outline_rounded,
        iconColor: NovaColors.danger,
        maxWidth: 380,
        onSubmit: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: _khataOutlinedButtonStyle(NovaColors.textSecondary),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: _khataFilledButtonStyle(NovaColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
        child: Text(
          'Remove ${person.name} and all pay later entries?',
          style: const TextStyle(
            color: NovaColors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ),
    );
    if (confirm != true) return;
    final deleted = await _service!.deletePerson(person.id);
    if (deleted) {
      _noticeKey.currentState?.show('Customer deleted.');
      _refresh();
    } else {
      _noticeKey.currentState?.show(
        'Customer was already removed. Refreshing ledger.',
        type: AppNoticeType.warning,
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) return const _PayLaterLoadingScaffold();
        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const _PayLaterLoadingScaffold();
        }

        final userEmail = auth.user?.email ?? '';
        final userName = auth.user?.name ?? userEmail.split('@').first;
        final isDesktop = AppNavigationShell.isDesktop(context);

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          bottomNavigationBar:
              !isDesktop ? const AppMobileBottomNavBar(currentIndex: 3) : null,
          appBar: AppNavigationAppBar(
            title: 'Pay Later Khata',
            icon: Icons.account_balance_wallet_rounded,
            photoUrl: auth.user?.photoUrl,
            userName: userName,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                mouseCursor: SystemMouseCursors.click,
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 20),
              ),
            ],
          ),
          body: AppNoticeHost(
            key: _noticeKey,
            child: AppNavigationShell(
              auth: auth,
              currentRoute: '/pay-later',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: FutureBuilder<List<PayLaterPerson>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: NovaColors.teal),
                      );
                    }
                    final people = _filtered(snapshot.data!);
                    final allPeople = snapshot.data!
                        .where((person) => person.khataType == _khataType)
                        .toList();
                    final totalDue = allPeople.fold(
                      0.0,
                      (sum, person) =>
                          sum + person.balance.clamp(0, double.infinity),
                    );
                    final overdueCount =
                        allPeople.where((person) => person.isOverdue).length;
                    final paidTotal = allPeople.fold(
                      0.0,
                      (sum, person) => sum + person.totalPaid,
                    );

                    return ListView(
                      children: [
                        _KhataTypeChips(
                          selected: _khataType,
                          onSelected: (value) =>
                              setState(() => _khataType = value),
                        ),
                        const SizedBox(height: 12),
                        _PayLaterHeader(
                          khataType: _khataType,
                          totalDue: _money(totalDue),
                          paidTotal: _money(paidTotal),
                          overdueCount: overdueCount,
                          onAddCustomer: () => _openPersonForm(),
                        ),
                        const SizedBox(height: 12),
                        _SearchBar(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        const SizedBox(height: 12),
                        if (people.isEmpty)
                          _EmptyLedger(onAddCustomer: () => _openPersonForm())
                        else
                          ...people.map(
                            (person) => _PayLaterCustomerCard(
                              key: ValueKey(
                                '${person.id}-${person.updatedAt?.microsecondsSinceEpoch ?? 0}-${person.entries.length}-${person.balance}',
                              ),
                              person: person,
                              cashKhata: _khataType == KhataType.cash,
                              balanceText: _money(person.balance),
                              onEdit: () => _openPersonForm(person: person),
                              onDebit: () => _openEntryForm(person, 'debit'),
                              onPayment: () =>
                                  _openEntryForm(person, 'payment'),
                              onDelete: () => _deletePerson(person),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

InputDecoration _khataFieldDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: NovaColors.textSecondary, fontSize: 12),
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: NovaColors.textSecondary, size: 18),
    filled: true,
    fillColor: NovaColors.bgSecondary,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: NovaColors.borderTertiary),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:
          const BorderSide(color: NovaColors.borderTertiary, width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: NovaColors.violet, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: NovaColors.danger, width: 1),
    ),
  );
}

ButtonStyle _khataFilledButtonStyle(Color color) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

ButtonStyle _khataOutlinedButtonStyle(Color color) {
  return OutlinedButton.styleFrom(
    foregroundColor: color,
    side: BorderSide(color: color.withOpacity(0.55)),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

class _KhataDialogFrame extends StatelessWidget {
  const _KhataDialogFrame({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    required this.actions,
    this.maxWidth = 440,
    this.onSubmit,
    this.onCancel,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 520;

    final dialog = Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: NovaColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded,
                          color: NovaColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: NovaColors.borderTertiary),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: NovaColors.bgSecondary,
                  border: Border(
                    top: BorderSide(color: NovaColors.borderTertiary),
                  ),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: actions
                            .map(
                              (action) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: action,
                              ),
                            )
                            .toList(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            actions[i],
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onSubmit == null && onCancel == null) return dialog;
    return CallbackShortcuts(
      bindings: {
        if (onSubmit != null)
          const SingleActivator(LogicalKeyboardKey.enter): onSubmit!,
        if (onSubmit != null)
          const SingleActivator(LogicalKeyboardKey.numpadEnter): onSubmit!,
        if (onCancel != null)
          const SingleActivator(LogicalKeyboardKey.escape): onCancel!,
      },
      child: Focus(autofocus: true, child: dialog),
    );
  }
}

class _PayLaterHeader extends StatelessWidget {
  const _PayLaterHeader({
    required this.khataType,
    required this.totalDue,
    required this.paidTotal,
    required this.overdueCount,
    required this.onAddCustomer,
  });

  final String khataType;
  final String totalDue;
  final String paidTotal;
  final int overdueCount;
  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    final isCash = khataType == KhataType.cash;
    final title = KhataType.label(khataType);
    final subtitle = isCash
        ? 'Standalone cash udhaar. It does not affect sales or profit reports.'
        : khataType == KhataType.repair
            ? 'Repair balances and payments only.'
            : 'Accessory and POS pay-later balances only.';
    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 760;
      final titleBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: NovaColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
      final stats = [
        _StatTile(
          label: 'Customers Owe',
          value: totalDue,
          icon: Icons.account_balance_wallet_rounded,
          color: NovaColors.violet,
        ),
        _StatTile(
          label: 'Received',
          value: paidTotal,
          icon: Icons.payments_rounded,
          color: NovaColors.teal,
        ),
        _StatTile(
          label: 'Overdue',
          value: overdueCount.toString(),
          icon: Icons.event_busy_rounded,
          color: NovaColors.danger,
        ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: isMobile
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              if (!isMobile)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: NovaColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                titleBlock,
              SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 10 : 0),
              SizedBox(
                width: isMobile ? double.infinity : 154,
                height: 40,
                child: FilledButton.icon(
                  onPressed: onAddCustomer,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Add Customer'),
                  style: _khataFilledButtonStyle(NovaColors.violet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isMobile
              ? Column(
                  children: stats
                      .map((stat) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: stat,
                          ))
                      .toList(),
                )
              : Row(
                  children: stats
                      .map((stat) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: stat,
                            ),
                          ))
                      .toList(),
                ),
        ],
      );
    });
  }
}

class _KhataTypeChips extends StatelessWidget {
  const _KhataTypeChips({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        KhataType.accessory,
        'Accessory Khata',
        Icons.headphones_battery_rounded,
      ),
      (KhataType.repair, 'Repair Khata', Icons.handyman_rounded),
      (KhataType.cash, 'Cash Udhaar', Icons.currency_rupee_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final active = selected == option.$1;
        return ChoiceChip(
          selected: active,
          showCheckmark: false,
          selectedColor: NovaColors.violetLight,
          backgroundColor: NovaColors.bgPrimary,
          side: BorderSide(
            color: active ? NovaColors.violet : NovaColors.borderSecondary,
            width: active ? 1.5 : 1,
          ),
          avatar: Icon(
            option.$3,
            size: 18,
            color: active ? NovaColors.violet : NovaColors.textSecondary,
          ),
          label: Text(
            option.$2,
            style: TextStyle(
              color: active ? NovaColors.violetDeep : NovaColors.textSecondary,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          onSelected: (_) => onSelected(option.$1),
        );
      }).toList(),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search customer, phone, or address',
        prefixIcon: const Icon(Icons.search_rounded,
            color: NovaColors.textSecondary, size: 20),
        filled: true,
        fillColor: NovaColors.bgPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NovaColors.borderTertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: NovaColors.borderTertiary, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NovaColors.violet, width: 1.5),
        ),
      ),
    );
  }
}

class _PayLaterCustomerCard extends StatelessWidget {
  const _PayLaterCustomerCard({
    super.key,
    required this.person,
    required this.cashKhata,
    required this.balanceText,
    required this.onEdit,
    required this.onDebit,
    required this.onPayment,
    required this.onDelete,
  });

  final PayLaterPerson person;
  final bool cashKhata;
  final String balanceText;
  final VoidCallback onEdit;
  final VoidCallback onDebit;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  String _date(DateTime? date) {
    if (date == null) return 'No due date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = person.isSettled
        ? NovaColors.teal
        : person.isOverdue
            ? NovaColors.danger
            : NovaColors.amber;
    final statusText = person.isSettled
        ? 'Settled'
        : person.isOverdue
            ? 'Overdue'
            : 'Pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.12),
              child: Icon(Icons.person_rounded, color: statusColor),
            ),
            title: Text(
              person.name,
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              [
                if (person.phone.isNotEmpty) person.phone,
                'Due ${_date(person.dueDate)}',
              ].join(' • '),
              style: const TextStyle(
                  color: NovaColors.textSecondary, fontSize: 12),
            ),
            trailing: SizedBox(
              width: 118,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balanceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: NovaColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            children: [
              Row(
                children: [
                  _MiniSummary(
                    label: cashKhata ? 'Cash Given' : 'Credit Sales',
                    value: person.totalDebit,
                  ),
                  const SizedBox(width: 8),
                  _MiniSummary(label: 'Received', value: person.totalPaid),
                  const SizedBox(width: 8),
                  _MiniSummary(label: 'Balance', value: person.balance),
                ],
              ),
              if (person.address.isNotEmpty || person.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    [person.address, person.note]
                        .where((value) => value.trim().isNotEmpty)
                        .join('\n'),
                    style: const TextStyle(
                      color: NovaColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, c) {
                final compact = c.maxWidth < 560;
                final buttons = [
                  _ActionChipButton(
                    label: cashKhata ? 'Give Cash' : 'Credit Sale',
                    icon: cashKhata
                        ? Icons.currency_rupee_rounded
                        : Icons.add_card_rounded,
                    color: NovaColors.amber,
                    onTap: onDebit,
                  ),
                  _ActionChipButton(
                    label: cashKhata ? 'Cash Returned' : 'Receive Payment',
                    icon: Icons.payments_rounded,
                    color: NovaColors.teal,
                    onTap: onPayment,
                  ),
                  _ActionChipButton(
                    label: 'Edit',
                    icon: Icons.edit_rounded,
                    color: NovaColors.violet,
                    onTap: onEdit,
                  ),
                  _ActionChipButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    color: NovaColors.danger,
                    onTap: onDelete,
                  ),
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        buttons[i],
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: buttons,
                );
              }),
              if (person.entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...person.entries
                    .take(8)
                    .map((entry) => _EntryRow(entry: entry)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSummary extends StatelessWidget {
  const _MiniSummary({required this.label, required this.value});

  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    final text =
        value is int ? value.toString() : 'Rs ${value.toStringAsFixed(0)}';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: NovaColors.bgSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: _khataOutlinedButtonStyle(color),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final PayLaterEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.isPayment ? NovaColors.teal : NovaColors.amber;
    final sign = entry.isPayment ? '-' : '+';
    final date = entry.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            entry.isPayment
                ? Icons.payments_rounded
                : Icons.receipt_long_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.note.isEmpty
                      ? (entry.isPayment ? 'Payment received' : 'Credit sale')
                      : entry.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                  '${entry.orderNumber == null ? '' : ' • Order ${entry.orderNumber}'}',
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign Rs ${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonFormDialog extends StatefulWidget {
  const _PersonFormDialog({
    required this.onSave,
    this.person,
    this.showInitialCashAmount = false,
  });

  final PayLaterPerson? person;
  final bool showInitialCashAmount;
  final Future<void> Function(
    String name,
    String phone,
    String address,
    String note,
    DateTime? dueDate,
    double initialAmount,
  ) onSave;

  @override
  State<_PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends State<_PersonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _note;
  late final TextEditingController _initialAmount;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _name = TextEditingController(text: person?.name ?? '');
    _phone = TextEditingController(text: person?.phone ?? '');
    _address = TextEditingController(text: person?.address ?? '');
    _note = TextEditingController(text: person?.note ?? '');
    _initialAmount = TextEditingController();
    _dueDate = person?.dueDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    _initialAmount.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    await widget.onSave(
      _name.text,
      _phone.text,
      _address.text,
      _note.text,
      _dueDate,
      double.tryParse(_initialAmount.text.trim()) ?? 0,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _dueDate == null
        ? 'Set Due Date'
        : '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}';
    return _KhataDialogFrame(
      title: widget.person == null ? 'Add Customer' : 'Edit Customer',
      icon: Icons.person_add_alt_1_rounded,
      iconColor: NovaColors.violet,
      maxWidth: 460,
      onSubmit: _save,
      onCancel: () => Navigator.pop(context, false),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: _khataOutlinedButtonStyle(NovaColors.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: _khataFilledButtonStyle(NovaColors.violet),
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: _khataFieldDecoration(
                'Customer Name',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              decoration: _khataFieldDecoration(
                'Phone Number',
                icon: Icons.call_outlined,
              ),
              keyboardType: TextInputType.phone,
            ),
            if (widget.showInitialCashAmount) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _initialAmount,
                autofocus: true,
                decoration: _khataFieldDecoration(
                  'Cash Given',
                  icon: Icons.currency_rupee_rounded,
                ).copyWith(
                  prefixText: 'Rs  ',
                  helperText: 'Initial cash udhaar given to this person.',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter the cash amount given';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _address,
              decoration: _khataFieldDecoration(
                'Address',
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              decoration: _khataFieldDecoration(
                'Note',
                icon: Icons.sticky_note_2_outlined,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event_rounded, size: 16),
                    label: Text(dueText),
                    style: _khataOutlinedButtonStyle(NovaColors.violet),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear due date',
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryFormDialog extends StatefulWidget {
  const _EntryFormDialog({
    required this.title,
    required this.actionLabel,
    required this.helperText,
    required this.icon,
    required this.color,
    required this.onSave,
    this.maxAmount,
  });

  final String title;
  final String actionLabel;
  final String helperText;
  final IconData icon;
  final Color color;
  final Future<bool> Function(double amount, String note) onSave;
  final double? maxAmount;

  @override
  State<_EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<_EntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final saved =
        await widget.onSave(double.parse(_amount.text.trim()), _note.text);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this customer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _KhataDialogFrame(
      title: widget.title,
      icon: widget.icon,
      iconColor: widget.color,
      maxWidth: 400,
      onSubmit: _save,
      onCancel: () => Navigator.pop(context, false),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          style: _khataOutlinedButtonStyle(NovaColors.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: _khataFilledButtonStyle(widget.color),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : widget.actionLabel),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.helperText,
                style: const TextStyle(
                  color: NovaColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              autofocus: true,
              decoration: _khataFieldDecoration(
                'Amount',
                icon: Icons.payments_outlined,
              ).copyWith(prefixText: 'Rs  '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                if (widget.maxAmount != null && amount > widget.maxAmount!) {
                  return 'Maximum remaining is Rs ${widget.maxAmount!.toStringAsFixed(0)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              decoration: _khataFieldDecoration(
                'Note',
                icon: Icons.sticky_note_2_outlined,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.onAddCustomer});

  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: NovaColors.textTertiary,
            size: 42,
          ),
          const SizedBox(height: 10),
          const Text(
            'No pay later customers yet',
            style: TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add a customer or select Pay Later at checkout.',
            style: TextStyle(color: NovaColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddCustomer,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Add Customer'),
            style: _khataFilledButtonStyle(NovaColors.violet),
          ),
        ],
      ),
    );
  }
}

class _PayLaterLoadingScaffold extends StatelessWidget {
  const _PayLaterLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NovaColors.bgTertiary,
      body: Center(child: CircularProgressIndicator(color: NovaColors.teal)),
    );
  }
}
