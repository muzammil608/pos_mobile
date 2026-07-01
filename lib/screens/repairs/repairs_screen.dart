import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/app_notice.dart';
import '../../core/constants/pakistan_mobile_catalog.dart';
import '../../models/repair_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pay_later_service.dart';
import '../../services/pocketbase/repair_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/repair_receipt_dialog.dart';

class RepairsScreen extends StatefulWidget {
  const RepairsScreen({super.key});

  @override
  State<RepairsScreen> createState() => _RepairsScreenState();
}

class _RepairsScreenState extends State<RepairsScreen> {
  RepairService? _service;
  final GlobalKey<AppNoticeHostState> _noticeKey =
      GlobalKey<AppNoticeHostState>();
  final _searchController = TextEditingController();
  Timer? _midnightRefreshTimer;
  String _query = '';
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _scheduleMidnightRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= RepairService(context.read<AuthProvider>().ownerId);
  }

  @override
  void dispose() {
    _midnightRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightRefreshTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isDesktop = AppNavigationShell.isDesktop(context);
        final email = auth.user?.email ?? '';
        final userName = auth.user?.name ??
            (email.contains('@') ? email.split('@').first : email);

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          bottomNavigationBar:
              isDesktop ? null : const AppMobileBottomNavBar(currentIndex: 4),
          appBar: AppNavigationAppBar(
            title: 'Repair Desk',
            icon: Icons.build_circle_rounded,
            photoUrl: auth.user?.photoUrl,
            userName: userName,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showRepairForm(),
            backgroundColor: CafeColors.flame,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New repair'),
          ),
          body: AppNoticeHost(
            key: _noticeKey,
            child: AppNavigationShell(
              auth: auth,
              currentRoute: '/repairs',
              child: StreamBuilder<List<Repair>>(
                stream: _service!.getRepairsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(onRetry: () => setState(() {}));
                  }

                  final repairs = snapshot.data ?? const <Repair>[];
                  final visible = _filter(repairs);
                  return _buildBody(repairs, visible);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<Repair> _filter(List<Repair> repairs) {
    final query = _query.trim().toLowerCase();
    return repairs.where((repair) {
      if (_status != 'all' && repair.status != _status) return false;
      if (query.isEmpty) return true;
      return [
        repair.jobId,
        repair.customerName,
        repair.customerPhone,
        repair.deviceBrand,
        repair.deviceModel,
        repair.serialNumber,
        repair.problemDescription,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Widget _buildBody(List<Repair> all, List<Repair> visible) {
    final active = all
        .where((repair) =>
            repair.status != RepairStatus.completed &&
            repair.status != RepairStatus.cancelled)
        .length;
    final ready = all
        .where((repair) => repair.status == RepairStatus.readyForPickup)
        .length;
    final outstanding = all.fold<double>(
      0,
      (sum, repair) => repair.status == RepairStatus.cancelled
          ? sum
          : sum + repair.remainingBalance,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final completedProfit = all.where((repair) {
      if (repair.status != RepairStatus.completed) return false;
      final completedAt = (repair.completedDate ?? repair.createdAt).toLocal();
      return !completedAt.isBefore(today) && completedAt.isBefore(tomorrow);
    }).fold<double>(0, (sum, repair) => sum + repair.profit);

    final summary = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryCard(
          label: 'Total jobs',
          value: '${all.length}',
          icon: Icons.receipt_long_rounded,
          color: NovaColors.violet,
        ),
        _SummaryCard(
          label: 'Active',
          value: '$active',
          icon: Icons.handyman_rounded,
          color: NovaColors.amber,
        ),
        _SummaryCard(
          label: 'Ready',
          value: '$ready',
          icon: Icons.task_alt_rounded,
          color: NovaColors.teal,
        ),
        _SummaryCard(
          label: 'Outstanding',
          value: 'Rs ${outstanding.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet_rounded,
          color: NovaColors.danger,
        ),
        _SummaryCard(
          label: "Today's received profit",
          value: 'Rs ${completedProfit.toStringAsFixed(0)}',
          icon: Icons.trending_up_rounded,
          color: NovaColors.teal,
        ),
      ],
    );

    final search = TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: 'Search job, customer, phone, device...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
    final filter = DropdownButtonFormField<String>(
      value: _status,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Repair status',
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All statuses')),
        ...RepairStatus.values.map(
          (status) => DropdownMenuItem(
            value: status,
            child: Text(RepairStatus.label(status)),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _status = value ?? 'all'),
    );

    Widget repairCard(int index) => _RepairCard(
          repair: visible[index],
          onEdit: () => _showRepairForm(repair: visible[index]),
          onDelete: () => _deleteRepair(visible[index]),
          onStatusChanged: (status) => _changeStatus(visible[index], status),
          onReceipt: () => _showReceipt(visible[index]),
        );

    if (MediaQuery.sizeOf(context).width < 650) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: summary,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedRepairSearchDelegate(
              child: Column(
                children: [
                  search,
                  const SizedBox(height: 8),
                  filter,
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                hasFilters: all.isNotEmpty,
                onAdd: () => _showRepairForm(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList.separated(
                itemCount: visible.length,
                itemBuilder: (_, index) => repairCard(index),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            children: [
              summary,
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      SizedBox(width: 220, child: filter),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  hasFilters: all.isNotEmpty,
                  onAdd: () => _showRepairForm(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => repairCard(index),
                ),
        ),
      ],
    );
  }

  Future<void> _changeStatus(Repair repair, String status) async {
    try {
      final updatedRepair = await _service!.updateStatus(repair.id, status);
      if (!mounted) return;
      _showNotice(
        '${repair.jobId} marked ${RepairStatus.label(status).toLowerCase()}',
        type: AppNoticeType.success,
      );
      if (status == RepairStatus.completed) {
        await _showReceipt(updatedRepair);
      }
    } catch (error) {
      if (!mounted) return;
      _showNotice(
        'Could not update repair status',
        subtitle: error.toString(),
        type: AppNoticeType.error,
      );
    }
  }

  Future<void> _showReceipt(Repair repair) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RepairReceiptDialog(repair: repair),
    );
  }

  Future<void> _deleteRepair(Repair repair) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteRepairDialog(repair: repair),
    );
    if (confirmed != true) return;

    try {
      await _service!.deleteRepair(repair.id);
      if (!mounted) return;
      _showNotice(
        '${repair.jobId} deleted',
        type: AppNoticeType.success,
      );
    } catch (error) {
      if (!mounted) return;
      _showNotice(
        'Could not delete repair',
        subtitle: error.toString(),
        type: AppNoticeType.error,
      );
    }
  }

  Future<void> _showRepairForm({Repair? repair}) async {
    final savedRepair = await showModalBottomSheet<Repair>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (context) {
        final screenSize = MediaQuery.sizeOf(context);
        final isDesktop = screenSize.width >= AppBreakpoints.tablet;

        return AppNoticeHost(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 0,
                isDesktop ? 24 : 0,
                isDesktop ? 24 : 0,
                isDesktop ? 24 : 0,
              ),
              child: _RepairFormSheet(
                repair: repair,
                service: _service!,
                isDesktop: isDesktop,
              ),
            ),
          ),
        );
      },
    );
    if (savedRepair != null && mounted) {
      _showNotice(
        repair == null ? 'Repair job created' : '${repair.jobId} updated',
        type: AppNoticeType.success,
      );
      await _showReceipt(savedRepair);
    }
  }

  void _showNotice(
    String message, {
    AppNoticeType type = AppNoticeType.info,
    String? subtitle,
  }) {
    _noticeKey.currentState?.show(
      message,
      type: type,
      subtitle: subtitle,
    );
  }
}

class _DeleteRepairDialog extends StatelessWidget {
  const _DeleteRepairDialog({required this.repair});

  final Repair repair;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.all(compact ? 18 : 22),
                decoration: BoxDecoration(
                  color: NovaColors.bgPrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NovaColors.borderTertiary),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: NovaColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: NovaColors.danger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete ${repair.jobId}?',
                                style: const TextStyle(
                                  color: NovaColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                repair.deviceName.isEmpty
                                    ? repair.customerName
                                    : repair.deviceName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: NovaColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'This repair record will be permanently removed.',
                      style: TextStyle(
                        color: NovaColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Flex(
                      direction: compact ? Axis.vertical : Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: compact ? double.infinity : null,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NovaColors.textPrimary,
                              side: const BorderSide(
                                color: NovaColors.borderSecondary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        SizedBox(
                            width: compact ? 0 : 10, height: compact ? 10 : 0),
                        SizedBox(
                          width: compact ? double.infinity : null,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: NovaColors.danger,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Delete repair'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RepairFormSheet extends StatefulWidget {
  const _RepairFormSheet({
    required this.repair,
    required this.service,
    required this.isDesktop,
  });

  final Repair? repair;
  final RepairService service;
  final bool isDesktop;

  @override
  State<_RepairFormSheet> createState() => _RepairFormSheetState();
}

class _RepairFormSheetState extends State<_RepairFormSheet> {
  static const _payLater = 'pay_later';
  static const _partialPayment = 'partial';
  static const _paidInFull = 'paid_full';

  static const _commonRepairWork = <String>[
    'Board work',
    'Charging base repair',
    'Soldering / jumper work',
    'Software repair',
    'Diagnosis / inspection',
  ];

  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final List<_RepairPartControllers> _partRows;
  late String _status;
  late String _selectedBrand;
  late String _selectedModel;
  late bool _manualBrand;
  late bool _manualModel;
  late String _paymentOption;
  late bool _showOptionalDetails;
  late bool _showParts;
  bool _syncingPayment = false;
  DateTime? _expectedDate;
  DateTime? _completedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final repair = widget.repair;
    _controllers = {
      'customerName': TextEditingController(text: repair?.customerName),
      'customerPhone': TextEditingController(
        text: _pakistanNationalNumber(repair?.customerPhone ?? ''),
      ),
      'deviceBrand': TextEditingController(text: repair?.deviceBrand),
      'deviceModel': TextEditingController(text: repair?.deviceModel),
      'serialNumber': TextEditingController(text: repair?.serialNumber),
      'problem': TextEditingController(text: repair?.problemDescription),
      'technician': TextEditingController(text: repair?.assignedTechnician),
      'notes': TextEditingController(text: repair?.technicianNotes),
      'labour': TextEditingController(
        text: repair == null ? '' : repair.labourCost.toStringAsFixed(0),
      ),
      'advance': TextEditingController(
        text: repair == null ? '' : repair.advancePayment.toStringAsFixed(0),
      ),
    };
    _selectedBrand = (repair?.deviceBrand ?? '').trim();
    _manualBrand = _selectedBrand.isNotEmpty &&
        !PakistanMobileCatalog.brandNames.contains(_selectedBrand);
    if (_selectedBrand.isEmpty || _manualBrand) {
      _selectedBrand = PakistanMobileCatalog.brandNames.first;
    }
    _selectedModel = (repair?.deviceModel ?? '').trim();
    _manualModel = _manualBrand ||
        (_selectedModel.isNotEmpty &&
            !PakistanMobileCatalog.modelsFor(_selectedBrand)
                .contains(_selectedModel));
    final availableModels = _modelsForSelectedBrand;
    if (_selectedModel.isEmpty || _manualModel) {
      _selectedModel = availableModels.first;
    }
    if (!_manualBrand) _controllers['deviceBrand']!.text = _selectedBrand;
    if (!_manualModel) _controllers['deviceModel']!.text = _selectedModel;
    _partRows = (repair?.partsUsed ?? const <RepairPart>[])
        .map(_RepairPartControllers.fromPart)
        .toList();
    _showParts = _partRows.isNotEmpty;
    if (_partRows.isEmpty) _partRows.add(_RepairPartControllers());
    _controllers['labour']!.addListener(_refreshTotals);
    _controllers['advance']!.addListener(_refreshTotals);
    for (final row in _partRows) {
      row.addListener(_refreshTotals);
    }
    final existingPayment = repair?.advancePayment ?? 0;
    if (existingPayment <= 0) {
      _paymentOption = _payLater;
    } else if (repair != null && repair.remainingBalance <= 0.01) {
      _paymentOption = _paidInFull;
    } else {
      _paymentOption = _partialPayment;
    }
    _status = repair?.status ?? RepairStatus.received;
    _expectedDate = repair?.expectedDeliveryDate;
    _completedDate = repair?.completedDate;
    _showOptionalDetails = repair != null &&
        (repair.serialNumber.isNotEmpty ||
            repair.assignedTechnician.isNotEmpty ||
            repair.expectedDeliveryDate != null ||
            repair.completedDate != null ||
            repair.status != RepairStatus.received);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final row in _partRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _refreshTotals() {
    if (!mounted || _syncingPayment) return;
    if (_paymentOption == _paidInFull) {
      _setAdvance(_repairTotal);
    } else if (_paymentOption == _payLater && _amount('advance') != 0) {
      _setAdvance(0);
    }
    setState(() {});
  }

  void _setAdvance(double value) {
    _syncingPayment = true;
    _controllers['advance']!.text =
        value == 0 ? '' : value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    _syncingPayment = false;
  }

  void _selectPaymentOption(String option) {
    setState(() {
      _paymentOption = option;
      if (option == _payLater) {
        _setAdvance(0);
      } else if (option == _paidInFull) {
        _setAdvance(_repairTotal);
      } else if (_amount('advance') >= _repairTotal) {
        _setAdvance(0);
      }
    });
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  List<String> get _brandOptions {
    final brands = PakistanMobileCatalog.brandNames;
    if (!brands.contains(_selectedBrand)) brands.add(_selectedBrand);
    return brands;
  }

  List<String> get _modelsForSelectedBrand {
    final models = PakistanMobileCatalog.modelsFor(_selectedBrand);
    final existingModel = _controllers['deviceModel']?.text.trim() ?? '';
    if (existingModel.isNotEmpty && !models.contains(existingModel)) {
      models.add(existingModel);
    }
    return models;
  }

  String? _pakistanPhoneValidator(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return 'Required';
    if (digits.length < 10) return 'Enter all 10 digits after +92';
    if (digits.length > 10) return 'Phone number is too long';
    if (!digits.startsWith('3')) {
      return 'Pakistan mobile number must start with 3';
    }
    return null;
  }

  double _amount(String key) =>
      double.tryParse(_controllers[key]!.text.trim()) ?? 0;

  List<RepairPart> get _parts => _partRows
      .map((row) => row.toPart())
      .where((part) => part.name.isNotEmpty)
      .toList();

  double get _partsPurchaseTotal =>
      _parts.fold(0, (sum, part) => sum + part.purchaseTotal);

  double get _partsSaleTotal =>
      _parts.fold(0, (sum, part) => sum + part.saleTotal);

  double get _repairTotal => _partsSaleTotal + _amount('labour');

  double get _balance =>
      (_repairTotal - _amount('advance')).clamp(0, double.infinity).toDouble();

  void _addPart() {
    final row = _RepairPartControllers()..addListener(_refreshTotals);
    setState(() => _partRows.add(row));
  }

  void _removePart(int index) {
    if (_partRows.length == 1) {
      _partRows.first.clear();
      return;
    }
    final row = _partRows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _showPhoneKeypad() async {
    final number = await showDialog<String>(
      context: context,
      builder: (context) => _PhoneKeypadDialog(
        initialValue: _controllers['customerPhone']!.text,
      ),
    );
    if (number == null) return;
    _controllers['customerPhone']!.text = number;
  }

  void _addRepairWork(String work) {
    final controller = _controllers['notes']!;
    final existing = controller.text.trim();
    if (existing.toLowerCase().contains(work.toLowerCase())) return;
    controller.text = existing.isEmpty ? work : '$existing\n$work';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  Future<void> _pickDate({required bool completed}) async {
    final current = completed ? _completedDate : _expectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      if (completed) {
        _completedDate = picked;
      } else {
        _expectedDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final total = _repairTotal;
    final labour = _amount('labour');
    final advance = _amount('advance');
    if (_paymentOption == _partialPayment &&
        (advance <= 0 || advance >= total)) {
      AppNotice.show(
        context,
        'Partial payment must be more than zero and less than the total',
        type: AppNoticeType.error,
      );
      return;
    }
    if (advance > total) {
      AppNotice.show(
        context,
        'Advance payment cannot exceed repair total',
        type: AppNoticeType.error,
      );
      return;
    }

    setState(() => _saving = true);
    final parts = _parts;

    try {
      late final Repair savedRepair;
      if (widget.repair == null) {
        savedRepair = await widget.service.createRepair(
          customerName: _controllers['customerName']!.text,
          customerPhone: '+92${_controllers['customerPhone']!.text}',
          deviceBrand: _controllers['deviceBrand']!.text,
          deviceModel: _controllers['deviceModel']!.text,
          serialNumber: _controllers['serialNumber']!.text,
          problemDescription: _controllers['problem']!.text,
          assignedTechnician: _controllers['technician']!.text,
          technicianNotes: _controllers['notes']!.text,
          estimatedCost: total,
          labourCost: labour,
          advancePayment: advance,
          partsUsed: parts,
          status: _status,
          expectedDeliveryDate: _expectedDate,
          completedDate: _completedDate,
        );
      } else {
        savedRepair = await widget.service.updateRepair(
          widget.repair!.id,
          values: {
            'customerName': _controllers['customerName']!.text.trim(),
            'customerPhone': '+92${_controllers['customerPhone']!.text.trim()}',
            'deviceBrand': _controllers['deviceBrand']!.text.trim(),
            'deviceModel': _controllers['deviceModel']!.text.trim(),
            'serialNumber': _controllers['serialNumber']!.text.trim(),
            'problemDescription': _controllers['problem']!.text.trim(),
            'assignedTechnician': _controllers['technician']!.text.trim(),
            'technicianNotes': _controllers['notes']!.text.trim(),
            'estimatedCost': total,
            'labourCost': labour,
            'advancePayment': advance,
            'partsUsed': parts.map((part) => part.toMap()).toList(),
            'status': _status,
            'expectedDeliveryDate':
                _expectedDate?.toUtc().toIso8601String() ?? '',
            'completedDate': _completedDate?.toUtc().toIso8601String() ?? '',
          },
        );
      }
      await PayLaterService(widget.service.ownerId).syncDebitForReference(
        reference: 'REPAIR-${savedRepair.jobId}',
        customerName: savedRepair.customerName,
        phone: savedRepair.customerPhone,
        amount: savedRepair.remainingBalance,
        note: '${savedRepair.jobId} repair balance for '
            '${savedRepair.deviceName.isEmpty ? "device repair" : savedRepair.deviceName}. '
            'Paid now Rs ${savedRepair.advancePayment.toStringAsFixed(0)}',
      );
      if (mounted) Navigator.pop(context, savedRepair);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppNotice.show(
        context,
        'Could not save repair job',
        subtitle: error.toString(),
        type: AppNoticeType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = widget.isDesktop
        ? (screenSize.height - 48).clamp(420.0, 820.0)
        : screenSize.height * 0.94;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: 960,
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isDesktop
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: widget.isDesktop
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        widget.isDesktop ? 28 : 20,
        widget.isDesktop ? 22 : 18,
        widget.isDesktop ? 28 : 20,
        (widget.isDesktop ? 24 : 20) + bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.repair == null
                        ? 'Create repair job'
                        : 'Edit ${widget.repair!.jobId}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 700
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _field(
                          width,
                          'customerName',
                          'Customer name',
                          Icons.person_outline_rounded,
                          validator: _required,
                          preventLabelOverlap: true,
                        ),
                        _field(
                          width,
                          'customerPhone',
                          'Customer mobile',
                          Icons.phone_outlined,
                          validator: _pakistanPhoneValidator,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          prefixText: '+92 ',
                          suffixIcon: IconButton(
                            tooltip: 'Open phone keypad',
                            onPressed: _showPhoneKeypad,
                            icon: const Icon(Icons.dialpad_rounded),
                          ),
                          preventLabelOverlap: true,
                        ),
                        _manualBrand
                            ? _field(
                                width,
                                'deviceBrand',
                                'Enter device brand',
                                Icons.devices_rounded,
                                validator: _required,
                                suffixIcon: IconButton(
                                  tooltip: 'Choose brand from list',
                                  onPressed: () {
                                    setState(() {
                                      _manualBrand = false;
                                      _manualModel = false;
                                      _selectedBrand = PakistanMobileCatalog
                                          .brandNames.first;
                                      _controllers['deviceBrand']!.text =
                                          _selectedBrand;
                                      _selectedModel =
                                          _modelsForSelectedBrand.first;
                                      _controllers['deviceModel']!.text =
                                          _selectedModel;
                                    });
                                  },
                                  icon: const Icon(Icons.list_rounded),
                                ),
                              )
                            : SizedBox(
                                width: width,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBrand,
                                  isExpanded: true,
                                  menuMaxHeight: 360,
                                  decoration: const InputDecoration(
                                    labelText: 'Device brand',
                                    prefixIcon: Icon(Icons.devices_rounded),
                                  ),
                                  items: _brandOptions
                                      .map(
                                        (brand) => DropdownMenuItem(
                                          value: brand,
                                          child: Text(
                                            brand == 'Other'
                                                ? 'Other / Enter manually'
                                                : brand,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (brand) {
                                    if (brand == null) return;
                                    if (brand == 'Other') {
                                      setState(() {
                                        _manualBrand = true;
                                        _manualModel = true;
                                        _controllers['deviceBrand']!.clear();
                                        _controllers['deviceModel']!.clear();
                                      });
                                      return;
                                    }
                                    final models =
                                        PakistanMobileCatalog.modelsFor(brand);
                                    setState(() {
                                      _selectedBrand = brand;
                                      _selectedModel = models.first;
                                      _manualModel = false;
                                      _controllers['deviceBrand']!.text = brand;
                                      _controllers['deviceModel']!.text =
                                          _selectedModel;
                                    });
                                  },
                                ),
                              ),
                        _manualModel
                            ? _field(
                                width,
                                'deviceModel',
                                'Enter device model',
                                Icons.smartphone_rounded,
                                validator: _required,
                                suffixIcon: _manualBrand
                                    ? null
                                    : IconButton(
                                        tooltip: 'Choose model from list',
                                        onPressed: () {
                                          setState(() {
                                            _manualModel = false;
                                            _selectedModel =
                                                _modelsForSelectedBrand.first;
                                            _controllers['deviceModel']!.text =
                                                _selectedModel;
                                          });
                                        },
                                        icon: const Icon(Icons.list_rounded),
                                      ),
                              )
                            : SizedBox(
                                width: width,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedModel,
                                  isExpanded: true,
                                  menuMaxHeight: 360,
                                  decoration: const InputDecoration(
                                    labelText: 'Device model',
                                    prefixIcon: Icon(Icons.smartphone_rounded),
                                  ),
                                  items: _modelsForSelectedBrand
                                      .map(
                                        (model) => DropdownMenuItem(
                                          value: model,
                                          child: Text(
                                            model,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (model) {
                                    if (model == null) return;
                                    if (model == 'Other / Custom model') {
                                      setState(() {
                                        _manualModel = true;
                                        _controllers['deviceModel']!.clear();
                                      });
                                      return;
                                    }
                                    setState(() {
                                      _selectedModel = model;
                                      _controllers['deviceModel']!.text = model;
                                    });
                                  },
                                ),
                              ),
                        SizedBox(
                          width: constraints.maxWidth,
                          child: _SimpleSectionToggle(
                            title: 'Optional job details',
                            subtitle: 'IMEI, technician, status and dates',
                            icon: Icons.tune_rounded,
                            expanded: _showOptionalDetails,
                            onTap: () => setState(
                              () =>
                                  _showOptionalDetails = !_showOptionalDetails,
                            ),
                          ),
                        ),
                        if (_showOptionalDetails)
                          _field(
                            width,
                            'serialNumber',
                            'IMEI / serial number',
                            Icons.qr_code_rounded,
                          ),
                        if (_showOptionalDetails)
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Repair status',
                                prefixIcon: Icon(Icons.flag_outlined),
                              ),
                              items: RepairStatus.values
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(RepairStatus.label(status)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _status = value!),
                            ),
                          ),
                        _field(
                          width,
                          'labour',
                          'Labour charges',
                          Icons.engineering_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: width,
                          child: _RepairPaymentOptions(
                            selected: _paymentOption,
                            payLaterValue: _payLater,
                            partialValue: _partialPayment,
                            paidFullValue: _paidInFull,
                            onSelected: _selectPaymentOption,
                          ),
                        ),
                        if (_paymentOption == _partialPayment)
                          _field(
                            width,
                            'advance',
                            'Amount paid now',
                            Icons.account_balance_wallet_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                          ),
                        if (_showOptionalDetails)
                          _field(
                            width,
                            'technician',
                            'Assigned technician',
                            Icons.engineering_outlined,
                          ),
                        if (_showOptionalDetails)
                          _DateField(
                            width: width,
                            label: 'Expected delivery date',
                            value: _expectedDate,
                            onTap: () => _pickDate(completed: false),
                            onClear: () => setState(() => _expectedDate = null),
                          ),
                        if (_showOptionalDetails &&
                            _status == RepairStatus.completed)
                          _DateField(
                            width: width,
                            label: 'Completed date',
                            value: _completedDate,
                            onTap: () => _pickDate(completed: true),
                            onClear: () =>
                                setState(() => _completedDate = null),
                          ),
                        _field(
                          constraints.maxWidth,
                          'problem',
                          'Problem description',
                          Icons.report_problem_outlined,
                          validator: _required,
                          maxLines: 3,
                        ),
                        _field(
                          constraints.maxWidth,
                          'notes',
                          'Repair work performed / technician notes',
                          Icons.handyman_outlined,
                          maxLines: 3,
                        ),
                        SizedBox(
                          width: constraints.maxWidth,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _commonRepairWork
                                .map(
                                  (work) => ActionChip(
                                    avatar: const Icon(
                                      Icons.add_rounded,
                                      size: 17,
                                    ),
                                    label: Text(work),
                                    onPressed: () => _addRepairWork(work),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        SizedBox(
                          width: constraints.maxWidth,
                          child: _SimpleSectionToggle(
                            title: 'Parts used',
                            subtitle: _showParts
                                ? 'Add purchase and sale prices'
                                : 'Optional — skip for board or service work',
                            icon: Icons.settings_suggest_outlined,
                            expanded: _showParts,
                            onTap: () =>
                                setState(() => _showParts = !_showParts),
                          ),
                        ),
                        if (_showParts)
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _PartsEditor(
                              rows: _partRows,
                              onAdd: _addPart,
                              onRemove: _removePart,
                            ),
                          ),
                        SizedBox(
                          width: constraints.maxWidth,
                          child: _RepairTotalsPanel(
                            purchaseTotal: _partsPurchaseTotal,
                            saleTotal: _partsSaleTotal,
                            labour: _amount('labour'),
                            total: _repairTotal,
                            profit: _repairTotal - _partsPurchaseTotal,
                            advance: _amount('advance'),
                            balance: _balance,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save repair job'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    double width,
    String key,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    Widget? suffixIcon,
    bool preventLabelOverlap = false,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: _controllers[key],
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          floatingLabelAlignment: FloatingLabelAlignment.start,
          alignLabelWithHint: maxLines > 1,
          prefixIcon: Icon(icon),
          prefixText: prefixText,
          suffixIcon: suffixIcon,
          isDense: false,
          contentPadding: preventLabelOverlap
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 20)
              : null,
        ),
      ),
    );
  }
}

String _pakistanNationalNumber(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0092')) digits = digits.substring(4);
  if (digits.startsWith('92')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = digits.substring(1);
  return digits.length > 10 ? digits.substring(0, 10) : digits;
}

class _PhoneKeypadDialog extends StatefulWidget {
  const _PhoneKeypadDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_PhoneKeypadDialog> createState() => _PhoneKeypadDialogState();
}

class _PhoneKeypadDialogState extends State<_PhoneKeypadDialog> {
  late String _number;

  @override
  void initState() {
    super.initState();
    _number = widget.initialValue.replaceAll(RegExp(r'\D'), '');
  }

  void _press(String digit) {
    if (_number.length >= 10) return;
    setState(() => _number += digit);
  }

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return AlertDialog(
      title: const Text('Customer mobile'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: NovaColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NovaColors.borderTertiary),
              ),
              child: Text(
                '+92 ${_number.isEmpty ? '__________' : _number}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: digits
                  .map(
                    (digit) => FilledButton.tonal(
                      onPressed: () => _press(digit),
                      child: Text(
                        digit,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _number = ''),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      if (_number.isEmpty) return;
                      setState(
                        () =>
                            _number = _number.substring(0, _number.length - 1),
                      );
                    },
                    child: const Icon(Icons.backspace_outlined),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _press('0'),
                    child: const Text(
                      '0',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _number.length == 10
              ? () => Navigator.pop(context, _number)
              : null,
          child: const Text('Use number'),
        ),
      ],
    );
  }
}

class _RepairCard extends StatefulWidget {
  const _RepairCard({
    required this.repair,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onReceipt,
  });

  final Repair repair;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onReceipt;

  @override
  State<_RepairCard> createState() => _RepairCardState();
}

class _RepairCardState extends State<_RepairCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final repair = widget.repair;
    final statusColor = _statusColor(repair.status);
    final completed = repair.status == RepairStatus.completed;
    final amountColor = completed
        ? NovaColors.teal
        : repair.remainingBalance > 0
            ? NovaColors.danger
            : NovaColors.teal;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: NovaColors.borderTertiary),
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.build_rounded, color: statusColor),
        ),
        title: Row(
          children: [
            Text(
              repair.jobId,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                repair.deviceName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 8,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${repair.customerName} · ${repair.customerPhone}'),
              _StatusChip(status: repair.status),
              Text(
                'Balance: Rs ${repair.remainingBalance.toStringAsFixed(0)}',
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Repair actions',
              onSelected: (value) {
                if (value == 'edit') {
                  widget.onEdit();
                } else if (value == 'receipt') {
                  widget.onReceipt();
                } else if (value == 'delete') {
                  widget.onDelete();
                } else {
                  widget.onStatusChanged(value);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit details'),
                  ),
                ),
                if (completed)
                  const PopupMenuItem(
                    value: 'receipt',
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.receipt_long_outlined,
                        color: NovaColors.teal,
                      ),
                      title: Text('View receipt'),
                    ),
                  ),
                ...RepairStatus.values
                    .where((status) => status != repair.status)
                    .map(
                      (status) => PopupMenuItem(
                        value: status,
                        child: Text('Mark ${RepairStatus.label(status)}'),
                      ),
                    ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    leading:
                        Icon(Icons.delete_outline, color: NovaColors.danger),
                    title: Text(
                      'Delete repair',
                      style: TextStyle(color: NovaColors.danger),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: NovaColors.textSecondary,
              ),
            ),
          ],
        ),
        children: [
          const Divider(),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Detail(label: 'IMEI / Serial', value: repair.serialNumber),
              _Detail(
                label: 'Created',
                value: _formatDate(repair.createdAt),
              ),
              _Detail(
                label: 'Expected delivery',
                value: _formatDate(repair.expectedDeliveryDate),
              ),
              _Detail(
                label: 'Completed',
                value: _formatDate(repair.completedDate),
              ),
              _Detail(
                label: 'Estimated cost',
                value: 'Rs ${repair.estimatedCost.toStringAsFixed(0)}',
                valueColor: completed ? NovaColors.teal : null,
              ),
              _Detail(
                label: 'Labour',
                value: 'Rs ${repair.labourCost.toStringAsFixed(0)}',
                valueColor: completed ? NovaColors.teal : null,
              ),
              _Detail(
                label: 'Parts purchase cost',
                value: 'Rs ${repair.partsPurchaseTotal.toStringAsFixed(0)}',
              ),
              _Detail(
                label: 'Parts sale total',
                value: 'Rs ${repair.partsSaleTotal.toStringAsFixed(0)}',
                valueColor: completed ? NovaColors.teal : null,
              ),
              _Detail(
                label: 'Net profit',
                value: 'Rs ${repair.profit.toStringAsFixed(0)}',
                valueColor:
                    repair.profit >= 0 ? NovaColors.teal : NovaColors.danger,
              ),
              _Detail(
                label: 'Payment status',
                value: repair.paymentStatus,
                valueColor: repair.remainingBalance <= 0.01
                    ? NovaColors.teal
                    : amountColor,
              ),
              _Detail(
                label: 'Amount paid',
                value: 'Rs ${repair.advancePayment.toStringAsFixed(0)}',
                valueColor: completed ? NovaColors.teal : null,
              ),
              _Detail(
                label: 'Remaining balance',
                value: 'Rs ${repair.remainingBalance.toStringAsFixed(0)}',
                valueColor: completed ? NovaColors.teal : amountColor,
              ),
              _Detail(
                label: 'Technician',
                value: repair.assignedTechnician,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Detail(
            label: 'Problem description',
            value: repair.problemDescription,
            fullWidth: true,
          ),
          if (repair.technicianNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Detail(
              label: 'Repair work performed',
              value: repair.technicianNotes,
              fullWidth: true,
            ),
          ],
          if (repair.partsUsed.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Detail(
              label: 'Parts used',
              value: repair.partsUsed
                  .map(
                    (part) => '${part.name} ×${part.quantity} '
                        '(Buy Rs ${part.purchasePrice.toStringAsFixed(0)}, '
                        'Sell Rs ${part.salePrice.toStringAsFixed(0)})',
                  )
                  .join('\n'),
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _RepairPartControllers {
  _RepairPartControllers({
    String name = '',
    String quantity = '1',
    String purchasePrice = '',
    String salePrice = '',
  })  : name = TextEditingController(text: name),
        quantity = TextEditingController(text: quantity),
        purchasePrice = TextEditingController(text: purchasePrice),
        salePrice = TextEditingController(text: salePrice);

  factory _RepairPartControllers.fromPart(RepairPart part) {
    return _RepairPartControllers(
      name: part.name,
      quantity: part.quantity.toString(),
      purchasePrice:
          part.purchasePrice == 0 ? '' : part.purchasePrice.toStringAsFixed(0),
      salePrice: part.salePrice == 0 ? '' : part.salePrice.toStringAsFixed(0),
    );
  }

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController purchasePrice;
  final TextEditingController salePrice;

  void addListener(VoidCallback listener) {
    name.addListener(listener);
    quantity.addListener(listener);
    purchasePrice.addListener(listener);
    salePrice.addListener(listener);
  }

  RepairPart toPart() => RepairPart(
        name: name.text.trim(),
        quantity: int.tryParse(quantity.text.trim()) ?? 1,
        purchasePrice: double.tryParse(purchasePrice.text.trim()) ?? 0,
        salePrice: double.tryParse(salePrice.text.trim()) ?? 0,
      );

  void clear() {
    name.clear();
    quantity.text = '1';
    purchasePrice.clear();
    salePrice.clear();
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
    purchasePrice.dispose();
    salePrice.dispose();
  }
}

class _PartsEditor extends StatelessWidget {
  const _PartsEditor({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_RepairPartControllers> rows;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Parts used',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add part'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NovaColors.violet,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: NovaColors.violet),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(
            rows.length,
            (index) => Padding(
              padding:
                  EdgeInsets.only(bottom: index == rows.length - 1 ? 0 : 10),
              child: _PartRow(
                controllers: rows[index],
                onRemove: () => onRemove(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.controllers,
    required this.onRemove,
  });

  final _RepairPartControllers controllers;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final numberFormatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final fields = [
          TextFormField(
            controller: controllers.name,
            decoration: const InputDecoration(
              labelText: 'Part name',
              prefixIcon: Icon(Icons.settings_suggest_outlined),
            ),
          ),
          TextFormField(
            controller: controllers.quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Qty'),
            validator: (value) {
              final quantity = int.tryParse(value ?? '');
              return quantity == null || quantity < 1 ? 'Minimum 1' : null;
            },
          ),
          TextFormField(
            controller: controllers.purchasePrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numberFormatters,
            decoration: const InputDecoration(labelText: 'Purchase price'),
          ),
          TextFormField(
            controller: controllers.salePrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numberFormatters,
            decoration: const InputDecoration(labelText: 'Sale price'),
          ),
        ];

        if (compact) {
          return Column(
            children: [
              ...fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: field,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove part'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NovaColors.danger,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: NovaColors.danger),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: fields[0]),
            const SizedBox(width: 8),
            SizedBox(width: 85, child: fields[1]),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: fields[2]),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: fields[3]),
            const SizedBox(width: 8),
            SizedBox(
              height: 50,
              width: 56,
              child: OutlinedButton(
                onPressed: onRemove,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NovaColors.danger,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: NovaColors.danger),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SimpleSectionToggle extends StatelessWidget {
  const _SimpleSectionToggle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: expanded ? NovaColors.violetLight : NovaColors.bgSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: expanded ? NovaColors.violet : NovaColors.borderTertiary,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: expanded ? NovaColors.violet : NovaColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: expanded
                            ? NovaColors.violetDeep
                            : NovaColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: NovaColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: expanded ? NovaColors.violet : NovaColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepairPaymentOptions extends StatelessWidget {
  const _RepairPaymentOptions({
    required this.selected,
    required this.payLaterValue,
    required this.partialValue,
    required this.paidFullValue,
    required this.onSelected,
  });

  final String selected;
  final String payLaterValue;
  final String partialValue;
  final String paidFullValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 20,
                color: NovaColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                'Payment option',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choice(
                value: payLaterValue,
                label: 'Pay later',
                icon: Icons.schedule_rounded,
              ),
              _choice(
                value: partialValue,
                label: 'Advance payment',
                icon: Icons.pie_chart_outline_rounded,
              ),
              _choice(
                value: paidFullValue,
                label: 'Full payment received',
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = selected == value;
    return ChoiceChip(
      selected: isSelected,
      selectedColor: NovaColors.violetLight,
      backgroundColor: NovaColors.bgPrimary,
      side: BorderSide(
        color: isSelected ? NovaColors.violet : NovaColors.borderSecondary,
        width: isSelected ? 1.5 : 1,
      ),
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? NovaColors.violet : NovaColors.textSecondary,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? NovaColors.violetDeep : NovaColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      showCheckmark: false,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _RepairTotalsPanel extends StatelessWidget {
  const _RepairTotalsPanel({
    required this.purchaseTotal,
    required this.saleTotal,
    required this.labour,
    required this.total,
    required this.profit,
    required this.advance,
    required this.balance,
  });

  final double purchaseTotal;
  final double saleTotal;
  final double labour;
  final double total;
  final double profit;
  final double advance;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.violetLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _row('Parts purchase cost', purchaseTotal),
          _row('Parts sale total', saleTotal),
          _row('Labour', labour),
          const Divider(),
          _row('Customer total', total, bold: true),
          _row('Net profit', profit),
          _row('Amount received', advance),
          _row('Balance due', balance, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      fontSize: bold ? 14 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('Rs ${amount.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}

class _PinnedRepairSearchDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedRepairSearchDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 132;

  @override
  double get maxExtent => 132;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: NovaColors.bgTertiary,
      elevation: overlapsContent ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedRepairSearchDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
    final available = MediaQuery.sizeOf(context).width;
    final width = available >= 1000
        ? (available - 380) / 4
        : available >= 600
            ? (available - 42) / 2
            : (available - 42) / 2;
    return Container(
      width: width.clamp(145, 270),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            foregroundColor: color,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 12,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        RepairStatus.label(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.fullWidth = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool fullWidth;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: NovaColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.trim().isEmpty ? '—' : value,
            style: valueColor == null
                ? null
                : TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.width,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final double width;
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: value == null
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          child: Text(_formatDate(value)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onAdd});

  final bool hasFilters;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.build_circle_outlined,
              size: 64,
              color: NovaColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No matching repair jobs' : 'No repair jobs yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!hasFilters) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create first repair'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 52),
          const SizedBox(height: 10),
          const Text('Could not load repair jobs'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case RepairStatus.completed:
    case RepairStatus.readyForPickup:
      return NovaColors.teal;
    case RepairStatus.cancelled:
      return NovaColors.danger;
    case RepairStatus.waitingForParts:
    case RepairStatus.awaitingApproval:
      return NovaColors.amber;
    case RepairStatus.inProgress:
    case RepairStatus.diagnosing:
      return NovaColors.violet;
    default:
      return NovaColors.textSecondary;
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Not set';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
