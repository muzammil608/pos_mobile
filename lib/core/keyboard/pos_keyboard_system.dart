import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../theme/nova_theme.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

bool get _supportsGlobalHotkeys =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS);

bool get _isEditingText {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null || primaryFocus.context == null) return false;
  return primaryFocus.context!.widget is EditableText ||
      primaryFocus.context!.findAncestorWidgetOfExactType<EditableText>() !=
          null;
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class ClearSearchIntent extends Intent {
  const ClearSearchIntent();
}

class NextCategoryIntent extends Intent {
  const NextCategoryIntent();
}

class PrevCategoryIntent extends Intent {
  const PrevCategoryIntent();
}

class CheckoutIntent extends Intent {
  const CheckoutIntent();
}

class ReadyOrdersIntent extends Intent {
  const ReadyOrdersIntent();
}

class NewOrderIntent extends Intent {
  const NewOrderIntent();
}

class OpenProductsIntent extends Intent {
  const OpenProductsIntent();
}

class InventoryIntent extends Intent {
  const InventoryIntent();
}

class ClearCartIntent extends Intent {
  const ClearCartIntent();
}

class ShowShortcutsIntent extends Intent {
  const ShowShortcutsIntent();
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class ConfirmItemIntent extends Intent {
  const ConfirmItemIntent();
}

class DeleteItemIntent extends Intent {
  const DeleteItemIntent();
}

class EditItemIntent extends Intent {
  const EditItemIntent();
}

class UndoCartIntent extends Intent {
  const UndoCartIntent();
}

class ArrowUpIntent extends Intent {
  const ArrowUpIntent();
}

class ArrowDownIntent extends Intent {
  const ArrowDownIntent();
}

class ArrowLeftIntent extends Intent {
  const ArrowLeftIntent();
}

class ArrowRightIntent extends Intent {
  const ArrowRightIntent();
}

class NumpadKeyIntent extends Intent {
  final String key;
  const NumpadKeyIntent(this.key);
}

class CheckoutBackIntent extends Intent {
  const CheckoutBackIntent();
}

class SelectPaymentMethodIntent extends Intent {
  final String method;
  const SelectPaymentMethodIntent(this.method);
}

class FocusCustomerPhoneIntent extends Intent {
  const FocusCustomerPhoneIntent();
}

class PosShortcuts {
  static Map<ShortcutActivator, Intent> posScreen = {
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const ClearSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
        const NextCategoryIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
        const PrevCategoryIntent(),
    const SingleActivator(LogicalKeyboardKey.f1): const NewOrderIntent(),
    const SingleActivator(LogicalKeyboardKey.f2): const ReadyOrdersIntent(),
    const SingleActivator(LogicalKeyboardKey.f3): const ClearCartIntent(),
    const SingleActivator(LogicalKeyboardKey.f4): const OpenProductsIntent(),
    const SingleActivator(LogicalKeyboardKey.f5): const RefreshIntent(),
    const SingleActivator(LogicalKeyboardKey.f6): const InventoryIntent(),
    const SingleActivator(LogicalKeyboardKey.enter, control: true):
        const CheckoutIntent(),
    const SingleActivator(LogicalKeyboardKey.delete, control: true):
        const ClearCartIntent(),
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
        const UndoCartIntent(),
    const SingleActivator(LogicalKeyboardKey.f7):
        SelectPaymentMethodIntent('cash'),
    const SingleActivator(LogicalKeyboardKey.f8):
        SelectPaymentMethodIntent('card'),
    const SingleActivator(LogicalKeyboardKey.f9):
        SelectPaymentMethodIntent('pay_later'),
    const SingleActivator(LogicalKeyboardKey.f11):
        const FocusCustomerPhoneIntent(),
    const SingleActivator(LogicalKeyboardKey.f12):
        SelectPaymentMethodIntent('partial'),
  };

  static Map<ShortcutActivator, Intent> numpad = {
    const SingleActivator(LogicalKeyboardKey.digit0): NumpadKeyIntent('0'),
    const SingleActivator(LogicalKeyboardKey.digit1): NumpadKeyIntent('1'),
    const SingleActivator(LogicalKeyboardKey.digit2): NumpadKeyIntent('2'),
    const SingleActivator(LogicalKeyboardKey.digit3): NumpadKeyIntent('3'),
    const SingleActivator(LogicalKeyboardKey.digit4): NumpadKeyIntent('4'),
    const SingleActivator(LogicalKeyboardKey.digit5): NumpadKeyIntent('5'),
    const SingleActivator(LogicalKeyboardKey.digit6): NumpadKeyIntent('6'),
    const SingleActivator(LogicalKeyboardKey.digit7): NumpadKeyIntent('7'),
    const SingleActivator(LogicalKeyboardKey.digit8): NumpadKeyIntent('8'),
    const SingleActivator(LogicalKeyboardKey.digit9): NumpadKeyIntent('9'),
    const SingleActivator(LogicalKeyboardKey.numpad0): NumpadKeyIntent('0'),
    const SingleActivator(LogicalKeyboardKey.numpad1): NumpadKeyIntent('1'),
    const SingleActivator(LogicalKeyboardKey.numpad2): NumpadKeyIntent('2'),
    const SingleActivator(LogicalKeyboardKey.numpad3): NumpadKeyIntent('3'),
    const SingleActivator(LogicalKeyboardKey.numpad4): NumpadKeyIntent('4'),
    const SingleActivator(LogicalKeyboardKey.numpad5): NumpadKeyIntent('5'),
    const SingleActivator(LogicalKeyboardKey.numpad6): NumpadKeyIntent('6'),
    const SingleActivator(LogicalKeyboardKey.numpad7): NumpadKeyIntent('7'),
    const SingleActivator(LogicalKeyboardKey.numpad8): NumpadKeyIntent('8'),
    const SingleActivator(LogicalKeyboardKey.numpad9): NumpadKeyIntent('9'),
    const SingleActivator(LogicalKeyboardKey.numpadDecimal):
        NumpadKeyIntent('.'),
    const SingleActivator(LogicalKeyboardKey.numpadAdd): NumpadKeyIntent('+'),
    const SingleActivator(LogicalKeyboardKey.backspace): NumpadKeyIntent('⌫'),
    const SingleActivator(LogicalKeyboardKey.period): NumpadKeyIntent('.'),
    const SingleActivator(LogicalKeyboardKey.enter): ConfirmItemIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): ConfirmItemIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE): EditItemIntent(),
    const SingleActivator(LogicalKeyboardKey.f10): CheckoutBackIntent(),
    const SingleActivator(LogicalKeyboardKey.f7):
        SelectPaymentMethodIntent('cash'),
    const SingleActivator(LogicalKeyboardKey.f8):
        SelectPaymentMethodIntent('card'),
    const SingleActivator(LogicalKeyboardKey.f9):
        SelectPaymentMethodIntent('pay_later'),
    const SingleActivator(LogicalKeyboardKey.f11):
        const FocusCustomerPhoneIntent(),
    const SingleActivator(LogicalKeyboardKey.f12):
        SelectPaymentMethodIntent('partial'),
  };
}

class PosHotkeyRegistry {
  PosHotkeyRegistry._();

  static final List<HotKey> _registered = [];
  static Future<void>? _initialization;

  static Future<void> init() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    if (!_supportsGlobalHotkeys) return;
    await hotKeyManager.unregisterAll();
  }

  static Future<void> register({
    required VoidCallback onF1NewOrder,
    required VoidCallback onF2Cart,
    required VoidCallback onF3HoldOrder,
    required VoidCallback onF4AddCustomer,
    required VoidCallback onF5Refresh,
    required VoidCallback onF6Inventory,
    required VoidCallback onCtrlF,
  }) async {
    if (!_supportsGlobalHotkeys) return;
    await init();
    await unregisterAll();

    final hotkeys = <(HotKey, VoidCallback)>[
      (
        HotKey(key: PhysicalKeyboardKey.f1, scope: HotKeyScope.inapp),
        onF1NewOrder
      ),
      (HotKey(key: PhysicalKeyboardKey.f2, scope: HotKeyScope.inapp), onF2Cart),
      (
        HotKey(key: PhysicalKeyboardKey.f3, scope: HotKeyScope.inapp),
        onF3HoldOrder
      ),
      (
        HotKey(key: PhysicalKeyboardKey.f4, scope: HotKeyScope.inapp),
        onF4AddCustomer
      ),
      (
        HotKey(key: PhysicalKeyboardKey.f5, scope: HotKeyScope.inapp),
        onF5Refresh
      ),
      (
        HotKey(key: PhysicalKeyboardKey.f6, scope: HotKeyScope.inapp),
        onF6Inventory
      ),
      (
        HotKey(
            key: PhysicalKeyboardKey.keyF,
            modifiers: [HotKeyModifier.control],
            scope: HotKeyScope.inapp),
        onCtrlF
      ),
    ];

    for (final (hotkey, callback) in hotkeys) {
      await hotKeyManager.register(
        hotkey,
        keyDownHandler: (_) => callback(),
      );
      _registered.add(hotkey);
    }
  }

  static Future<void> unregisterAll() async {
    if (!_supportsGlobalHotkeys) return;
    final copy = List<HotKey>.from(_registered);
    _registered.clear();
    for (final hk in copy) {
      await hotKeyManager.unregister(hk);
    }
  }
}

class CartUndoStack {
  static final CartUndoStack instance = CartUndoStack._();
  CartUndoStack._();

  final List<_UndoEntry> _stack = [];
  static const int _maxEntries = 20;

  void push(String description, VoidCallback undoFn) {
    if (_stack.length >= _maxEntries) _stack.removeAt(0);
    _stack.add(_UndoEntry(description, undoFn));
  }

  bool get canUndo => _stack.isNotEmpty;
  String? get lastDescription =>
      _stack.isEmpty ? null : _stack.last.description;

  void undo() {
    if (_stack.isEmpty) return;
    _stack.removeLast().undoFn();
  }

  void clear() => _stack.clear();
}

class _UndoEntry {
  final String description;
  final VoidCallback undoFn;
  _UndoEntry(this.description, this.undoFn);
}

class PosKeyboardScope extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final GlobalKey<PosSearchBarState>? searchBarKey;
  final GlobalKey<PosCategoryChipsState>? categoryChipsKey;
  final VoidCallback? onNewOrder;
  final VoidCallback? onCheckout;
  final VoidCallback? onReadyOrders;
  final VoidCallback? onProducts;
  final VoidCallback? onInventory;
  final VoidCallback? onClearCart;
  final VoidCallback? onDeleteFocusedItem;
  final VoidCallback? onEditFocusedItem;
  final VoidCallback? onUndoCart;
  final VoidCallback? onConfirmFocusedItem;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;
  final VoidCallback? onRefresh;
  final VoidCallback? onEscape;
  final VoidCallback? onFocusCustomerPhone;

  final ValueChanged<String>? onSelectPaymentMethod;

  const PosKeyboardScope({
    super.key,
    required this.child,
    this.enabled = true,
    this.searchBarKey,
    this.categoryChipsKey,
    this.onNewOrder,
    this.onCheckout,
    this.onReadyOrders,
    this.onProducts,
    this.onInventory,
    this.onClearCart,
    this.onDeleteFocusedItem,
    this.onEditFocusedItem,
    this.onUndoCart,
    this.onConfirmFocusedItem,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowLeft,
    this.onArrowRight,
    this.onRefresh,
    this.onEscape,
    this.onFocusCustomerPhone,
    this.onSelectPaymentMethod,
  });

  @override
  State<PosKeyboardScope> createState() => _PosKeyboardScopeState();
}

class _PosKeyboardScopeState extends State<PosKeyboardScope> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    }
  }

  @override
  void didUpdateWidget(covariant PosKeyboardScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    }
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final searchBar = widget.searchBarKey?.currentState;
    final searchHasFocus = searchBar?.hasFocus ?? false;
    final isTextEditing = _isEditingText;

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      widget.onNewOrder?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f2) {
      widget.onReadyOrders?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f3) {
      widget.onClearCart?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f4) {
      widget.onProducts?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f6) {
      widget.onInventory?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyF &&
        HardwareKeyboard.instance.isControlPressed) {
      searchBar?.requestFocus();
      return true;
    }

    if (event.character == '/' ||
        (event.logicalKey == LogicalKeyboardKey.slash &&
            !HardwareKeyboard.instance.isShiftPressed)) {
      if (!searchHasFocus) {
        if (_isDesktop) {
          PosShortcutHelp.show(context);
        }
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.onEscape != null) {
        widget.onEscape!.call();
      } else {
        searchBar?.clear();
      }
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f7) {
      widget.onSelectPaymentMethod?.call('cash');
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f8) {
      widget.onSelectPaymentMethod?.call('card');
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f9) {
      widget.onSelectPaymentMethod?.call('pay_later');
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f12) {
      widget.onSelectPaymentMethod?.call('partial');
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.f11) {
      widget.onFocusCustomerPhone?.call();
      return widget.onFocusCustomerPhone != null;
    }

    if (event.logicalKey == LogicalKeyboardKey.f5) {
      widget.onRefresh?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isControlPressed) {
      widget.onCheckout?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (!searchHasFocus) {
        widget.onConfirmFocusedItem?.call();
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (!searchHasFocus && !isTextEditing) {
        widget.onDeleteFocusedItem?.call();
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      if (!searchHasFocus && !isTextEditing) {
        widget.onEditFocusedItem?.call();
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onArrowUp?.call();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onArrowDown?.call();
      return true;
    }

    final hasCtrl = HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (hasCtrl) {
        widget.categoryChipsKey?.currentState?.prevCategory();
        return true;
      } else if (!searchHasFocus ||
          (searchBar?.widget.controller.text.isEmpty ?? true)) {
        widget.onArrowLeft?.call();
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (hasCtrl) {
        widget.categoryChipsKey?.currentState?.nextCategory();
        return true;
      } else if (!searchHasFocus ||
          (searchBar?.widget.controller.text.isEmpty ?? true)) {
        widget.onArrowRight?.call();
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Shortcuts(
      shortcuts: PosShortcuts.posScreen,
      child: Actions(
        actions: {
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (_) {
              widget.searchBarKey?.currentState?.requestFocus();
              return null;
            },
          ),
          ClearSearchIntent: CallbackAction<ClearSearchIntent>(
            onInvoke: (_) {
              if (widget.onEscape != null) {
                widget.onEscape!.call();
              } else {
                widget.searchBarKey?.currentState?.clear();
              }
              return null;
            },
          ),
          NextCategoryIntent: CallbackAction<NextCategoryIntent>(
            onInvoke: (_) {
              widget.categoryChipsKey?.currentState?.nextCategory();
              return null;
            },
          ),
          PrevCategoryIntent: CallbackAction<PrevCategoryIntent>(
            onInvoke: (_) {
              widget.categoryChipsKey?.currentState?.prevCategory();
              return null;
            },
          ),
          CheckoutIntent: CallbackAction<CheckoutIntent>(
            onInvoke: (_) {
              widget.onCheckout?.call();
              return null;
            },
          ),
          NewOrderIntent: CallbackAction<NewOrderIntent>(
            onInvoke: (_) {
              widget.onNewOrder?.call();
              return null;
            },
          ),
          ReadyOrdersIntent: CallbackAction<ReadyOrdersIntent>(
            onInvoke: (_) {
              widget.onReadyOrders?.call();
              return null;
            },
          ),
          OpenProductsIntent: CallbackAction<OpenProductsIntent>(
            onInvoke: (_) {
              widget.onProducts?.call();
              return null;
            },
          ),
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (_) {
              widget.onRefresh?.call();
              return null;
            },
          ),
          InventoryIntent: CallbackAction<InventoryIntent>(
            onInvoke: (_) {
              widget.onInventory?.call();
              return null;
            },
          ),
          ClearCartIntent: CallbackAction<ClearCartIntent>(
            onInvoke: (_) {
              widget.onClearCart?.call();
              return null;
            },
          ),
          DeleteItemIntent: CallbackAction<DeleteItemIntent>(
            onInvoke: (_) {
              final searchHasFocus =
                  widget.searchBarKey?.currentState?.hasFocus ?? false;
              final isTextEditing = _isEditingText;
              if (!searchHasFocus && !isTextEditing) {
                widget.onDeleteFocusedItem?.call();
              }
              return null;
            },
          ),
          EditItemIntent: CallbackAction<EditItemIntent>(
            onInvoke: (_) {
              final searchHasFocus =
                  widget.searchBarKey?.currentState?.hasFocus ?? false;
              final isTextEditing = _isEditingText;
              if (!searchHasFocus && !isTextEditing) {
                widget.onEditFocusedItem?.call();
              }
              return null;
            },
          ),
          UndoCartIntent: CallbackAction<UndoCartIntent>(
            onInvoke: (_) {
              final searchHasFocus =
                  widget.searchBarKey?.currentState?.hasFocus ?? false;
              if (!searchHasFocus) {
                widget.onUndoCart?.call();
              }
              return null;
            },
          ),
          ConfirmItemIntent: CallbackAction<ConfirmItemIntent>(
            onInvoke: (_) {
              final searchHasFocus =
                  widget.searchBarKey?.currentState?.hasFocus ?? false;
              if (!searchHasFocus) {
                widget.onConfirmFocusedItem?.call();
              }
              return null;
            },
          ),
          ShowShortcutsIntent: CallbackAction<ShowShortcutsIntent>(
            onInvoke: (_) {
              final searchHasFocus =
                  widget.searchBarKey?.currentState?.hasFocus ?? false;
              if (!searchHasFocus && _isDesktop) {
                PosShortcutHelp.show(context);
              }
              return null;
            },
          ),
          SelectPaymentMethodIntent: CallbackAction<SelectPaymentMethodIntent>(
            onInvoke: (intent) {
              widget.onSelectPaymentMethod?.call(intent.method);
              return null;
            },
          ),
          FocusCustomerPhoneIntent: CallbackAction<FocusCustomerPhoneIntent>(
            onInvoke: (_) {
              widget.onFocusCustomerPhone?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }
}

class CheckoutKeyboardScope extends StatefulWidget {
  final Widget child;
  final TextEditingController? cashController;
  final FocusNode? cashFocusNode;
  final FocusNode? shortcutFocusNode;
  final ValueChanged<String>? onCashChanged;
  final VoidCallback? onBack;
  final VoidCallback? onConfirm;
  final VoidCallback? onEditFocusedItem;
  final VoidCallback? onDeleteFocusedItem;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onFocusCustomerPhone;

  final ValueChanged<String>? onSelectPaymentMethod;
  final bool autofocusCash;
  final bool enabled;

  const CheckoutKeyboardScope({
    super.key,
    required this.child,
    this.cashController,
    this.cashFocusNode,
    this.shortcutFocusNode,
    this.onCashChanged,
    this.onBack,
    this.onConfirm,
    this.onEditFocusedItem,
    this.onDeleteFocusedItem,
    this.onArrowUp,
    this.onArrowDown,
    this.onFocusCustomerPhone,
    this.onSelectPaymentMethod,
    this.autofocusCash = true,
    this.enabled = true,
  });

  @override
  State<CheckoutKeyboardScope> createState() => _CheckoutKeyboardScopeState();
}

class _CheckoutKeyboardScopeState extends State<CheckoutKeyboardScope> {
  bool _backInProgress = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled && widget.autofocusCash) {
        widget.cashFocusNode?.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CheckoutKeyboardScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    }
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final logicalKey = event.logicalKey;
    final isTextEditing = _isEditingText;
    final isBackToPos = logicalKey == LogicalKeyboardKey.f10;

    if (isBackToPos) {
      _goBackOnce();
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.f7) {
      widget.onSelectPaymentMethod?.call('cash');
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.f8) {
      widget.onSelectPaymentMethod?.call('card');
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.f9) {
      widget.onSelectPaymentMethod?.call('pay_later');
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.f12) {
      widget.onSelectPaymentMethod?.call('partial');
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.f11) {
      widget.onFocusCustomerPhone?.call();
      return widget.onFocusCustomerPhone != null;
    }

    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
      widget.onConfirm?.call();
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.keyE && !isTextEditing) {
      widget.onEditFocusedItem?.call();
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!isTextEditing) {
        widget.onArrowUp?.call();
        return true;
      }
      return false;
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!isTextEditing) {
        widget.onArrowDown?.call();
        return true;
      }
      return false;
    }

    if (isTextEditing) return false;
    if (logicalKey == LogicalKeyboardKey.delete) {
      widget.onDeleteFocusedItem?.call();
      return true;
    }

    return false;
  }

  void _goBackOnce() {
    if (_backInProgress) return;
    _backInProgress = true;
    widget.onBack?.call();
  }

  void _handleNumpad(String key) {
    final ctrl = widget.cashController;
    if (ctrl == null) return;

    final hasFocus =
        widget.cashFocusNode == null || widget.cashFocusNode!.hasFocus;
    if (!hasFocus) return;

    final current = ctrl.text;
    late String next;
    if (key == '⌫') {
      next = current.isEmpty ? '' : current.substring(0, current.length - 1);
    } else if (key == '.') {
      next = current.contains('.') ? current : '$current.';
    } else if (key == '+') {
      return;
    } else {
      next = current.isEmpty || current == '0' ? key : '$current$key';
    }
    ctrl.text = next;
    ctrl.selection = TextSelection.collapsed(offset: next.length);
    widget.onCashChanged?.call(next);
  }

  Map<ShortcutActivator, Intent> get _checkoutShortcuts {
    return Map<ShortcutActivator, Intent>.fromEntries(
      PosShortcuts.numpad.entries.where(
        (entry) =>
            entry.value is! ArrowUpIntent && entry.value is! ArrowDownIntent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Shortcuts(
      shortcuts: _checkoutShortcuts,
      child: Actions(
        actions: {
          NumpadKeyIntent: CallbackAction<NumpadKeyIntent>(
            onInvoke: (intent) {
              _handleNumpad(intent.key);
              return null;
            },
          ),
          ConfirmItemIntent: CallbackAction<ConfirmItemIntent>(
            onInvoke: (_) {
              widget.onConfirm?.call();
              return null;
            },
          ),
          EditItemIntent: CallbackAction<EditItemIntent>(
            onInvoke: (_) {
              final isTextEditing = _isEditingText;
              if (!isTextEditing) {
                widget.onEditFocusedItem?.call();
              }
              return null;
            },
          ),
          DeleteItemIntent: CallbackAction<DeleteItemIntent>(
            onInvoke: (_) {
              final isTextEditing = _isEditingText;
              if (!isTextEditing) {
                widget.onDeleteFocusedItem?.call();
              }
              return null;
            },
          ),
          CheckoutBackIntent: CallbackAction<CheckoutBackIntent>(
            onInvoke: (_) {
              _goBackOnce();
              return null;
            },
          ),
          SelectPaymentMethodIntent: CallbackAction<SelectPaymentMethodIntent>(
            onInvoke: (intent) {
              widget.onSelectPaymentMethod?.call(intent.method);
              return null;
            },
          ),
          FocusCustomerPhoneIntent: CallbackAction<FocusCustomerPhoneIntent>(
            onInvoke: (_) {
              widget.onFocusCustomerPhone?.call();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: widget.shortcutFocusNode,
          autofocus: false,
          child: widget.child,
        ),
      ),
    );
  }
}

class PosFocusIndicator extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color focusColor;

  const PosFocusIndicator({
    super.key,
    required this.child,
    this.focusNode,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.focusColor = const Color(0xFF534AB7),
  });

  @override
  State<PosFocusIndicator> createState() => _PosFocusIndicatorState();
}

class _PosFocusIndicatorState extends State<PosFocusIndicator> {
  late FocusNode _node;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _node.requestFocus();
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: widget.focusColor.withValues(alpha: 0.35),
                    blurRadius: 0,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Focus(focusNode: _node, child: widget.child),
      ),
    );
  }
}

class PosSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String? hintText;
  final double height;

  const PosSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText,
    this.height = 42,
  });

  @override
  State<PosSearchBar> createState() => PosSearchBarState();
}

class PosSearchBarState extends State<PosSearchBar> {
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  bool get hasFocus => focusNode.hasFocus;

  void requestFocus() => FocusScope.of(context).requestFocus(focusNode);

  void clear() {
    widget.controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
    focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE4E4E8),
          width: 0.5,
        ),
        boxShadow: const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: focusNode,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        cursorColor: NovaColors.violet,
        style: const TextStyle(fontSize: 14, color: Color(0xFF111118)),
        decoration: InputDecoration(
          hintText: widget.hintText ??
              (_isDesktop ? 'Search items…  (Ctrl+F)' : 'Search items…'),
          hintStyle: const TextStyle(color: Color(0xFF9999AE), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF6B6B80), size: 18),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF9999AE), size: 16),
                  onPressed: clear,
                  tooltip: 'Clear (Esc)',
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

class PosCategoryChips extends StatefulWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const PosCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<PosCategoryChips> createState() => PosCategoryChipsState();
}

class PosCategoryChipsState extends State<PosCategoryChips> {
  final ScrollController _scroll = ScrollController();
  static const double _estimatedChipWidth = 100.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void nextCategory() {
    final i = widget.categories.indexOf(widget.selected);
    if (i < widget.categories.length - 1) {
      widget.onSelected(widget.categories[i + 1]);
      _scrollToIndex(i + 1);
    }
  }

  void prevCategory() {
    final i = widget.categories.indexOf(widget.selected);
    if (i > 0) {
      widget.onSelected(widget.categories[i - 1]);
      _scrollToIndex(i - 1);
    }
  }

  void _scrollToIndex(int i) {
    if (!_scroll.hasClients) return;
    final offset =
        (i * _estimatedChipWidth).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(offset,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final rowHeight = isCompact ? 32.0 : 36.0;

        return SizedBox(
          height: rowHeight,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
            itemCount: widget.categories.length,
            separatorBuilder: (_, __) => SizedBox(width: isCompact ? 4 : 5),
            itemBuilder: (context, index) {
              final cat = widget.categories[index];
              final isSelected = widget.selected == cat;
              return Center(
                child: _CategoryChip(
                  label: cat,
                  isSelected: isSelected,
                  isCompact: isCompact,
                  onTap: () => widget.onSelected(cat),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });
  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: widget.isCompact ? 26 : 30,
            constraints: BoxConstraints(maxWidth: widget.isCompact ? 110 : 145),
            alignment: Alignment.center,
            padding:
                EdgeInsets.symmetric(horizontal: widget.isCompact ? 9 : 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFF534AB7)
                  : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _focused
                    ? const Color(0xFF534AB7)
                    : widget.isSelected
                        ? const Color(0xFF534AB7)
                        : const Color(0xFFE4E4E8),
                width: _focused ? 2 : 0.5,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                          color: const Color(0xFF534AB7).withValues(alpha: 0.2),
                          blurRadius: 6)
                    ]
                  : [],
            ),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.isCompact ? 10.5 : 11.5,
                height: 1.0,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    widget.isSelected ? Colors.white : const Color(0xFF6B6B80),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PosNumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<double> quickAmounts;

  const PosNumericKeypad({
    super.key,
    required this.controller,
    required this.onChanged,
    this.quickAmounts = const [500, 1000, 2000, 5000],
  });

  void _press(String key) {
    final current = controller.text;
    late String next;
    if (key == '⌫') {
      next = current.isEmpty ? '' : current.substring(0, current.length - 1);
    } else if (key == 'C') {
      next = '';
    } else if (key == '.') {
      next = current.contains('.') ? current : '$current.';
    } else {
      next = current.isEmpty || current == '0' ? key : '$current$key';
    }
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: quickAmounts
              .map((amount) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _QuickAmountButton(
                        label: 'Rs ${amount.toInt()}',
                        onTap: () {
                          final text = amount.toInt().toString();
                          controller.text = text;
                          controller.selection =
                              TextSelection.collapsed(offset: text.length);
                          onChanged(text);
                        },
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 2.2,
          children: ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '⌫']
              .map((k) => _NumpadKey(label: k, onPress: _press))
              .toList(),
        ),
      ],
    );
  }
}

class _NumpadKey extends StatefulWidget {
  final String label;
  final ValueChanged<String> onPress;
  const _NumpadKey({required this.label, required this.onPress});
  @override
  State<_NumpadKey> createState() => _NumpadKeyState();
}

class _NumpadKeyState extends State<_NumpadKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isDelete => widget.label == '⌫';

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onPress(widget.label);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onPress(widget.label);
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: _isDelete
                  ? const Color(0xFFFFEDE8)
                  : _focused
                      ? const Color(0xFFEEEDFE)
                      : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused
                    ? const Color(0xFF534AB7)
                    : const Color(0xFFE4E4E8),
                width: _focused ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: _isDelete
                  ? const Icon(Icons.backspace_outlined,
                      color: Color(0xFFD85A30), size: 18)
                  : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _focused
                            ? const Color(0xFF534AB7)
                            : const Color(0xFF111118),
                      ),
                    ),
            ),
          ),
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmountButton({required this.label, required this.onTap});
  @override
  State<_QuickAmountButton> createState() => _QuickAmountButtonState();
}

class _QuickAmountButtonState extends State<_QuickAmountButton> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF534AB7) : const Color(0xFFEEEDFE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused
                  ? const Color(0xFF534AB7)
                  : const Color(0xFF534AB7).withValues(alpha: 0.3),
              width: _focused ? 1.5 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _focused ? Colors.white : const Color(0xFF534AB7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PosShortcutHelp extends StatelessWidget {
  const PosShortcutHelp({super.key});

  static void show(BuildContext context) {
    if (!_isDesktop) return;
    showDialog(context: context, builder: (_) => const PosShortcutHelp());
  }

  @override
  Widget build(BuildContext context) {
    const groups = [
      (
        'Navigation',
        [
          ('Ctrl+F', 'Focus product search'),
          ('Ctrl+→ / Ctrl+←', 'Next / prev category'),
          ('↑ ↓ ← →', 'Navigate product list'),
          ('Tab / Shift+Tab', 'Move between fields'),
        ]
      ),
      (
        'F-Keys',
        [
          ('F1', 'New order / go to POS'),
          ('F2', 'Ready orders'),
          ('F3', 'Clear current order'),
          ('F4', 'Open products'),
          ('F5', 'Refresh products'),
          ('F6', 'Open inventory'),
        ]
      ),
      (
        'Actions',
        [
          ('Enter', 'Confirm / add focused item'),
          ('Escape', 'Cancel dialog / clear search'),
          ('E', 'Edit focused item qty'),
          ('Delete', 'Remove last cart item'),
          ('Ctrl+Z', 'Undo last cart action'),
          ('Ctrl+Enter', 'Go to checkout'),
          ('Ctrl+Delete', 'Clear entire cart'),
        ]
      ),
      (
        'Checkout',
        [
          ('0–9 / Numpad', 'Enter cash amount'),
          ('Backspace', 'Delete last digit'),
          ('Enter', 'Confirm payment'),
          ('F9', 'Select Pay Later'),
          ('F10', 'Back to POS'),
          ('F11', 'Focus mobile number'),
          ('F12', 'Select Partial Payment'),
          ('F7', 'Select Cash payment'),
          ('F8', 'Select Card payment'),
        ]
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFFFFFF),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEDFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.keyboard_rounded,
                          color: Color(0xFF534AB7), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text('Keyboard Shortcuts',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111118))),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close (Esc)',
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF9999AE), size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: groups.map((group) {
                    return SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.$1,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF534AB7),
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          ...group.$2.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _KeyBadge(s.$1),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(s.$2,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B6B80))),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text('Press  /  anytime to show this',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9999AE),
                          fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String label;
  const _KeyBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F2),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFCCCCD4), width: 0.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111118),
            fontFamily: 'monospace',
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
