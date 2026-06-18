import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/nova_theme.dart';
import '../services/pocketbase/report_service.dart';

class StatusDonutChart extends StatefulWidget {
  final String ownerId;
  final bool compact;
  final double? cardHeight;
  final double chartSize;
  final bool showSegmentBar;

  const StatusDonutChart({
    super.key,
    required this.ownerId,
    this.compact = false,
    this.cardHeight,
    this.chartSize = 160,
    this.showSegmentBar = true,
  });

  @override
  State<StatusDonutChart> createState() => _StatusDonutChartState();
}

class _StatusDonutChartState extends State<StatusDonutChart>
    with SingleTickerProviderStateMixin {
  int? _touchedItemIndex;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const _items = [
    _DonutMeta(
      label: 'Pending',
      colorKey: 'danger',
      icon: Icons.hourglass_top_rounded,
    ),
    _DonutMeta(
      label: 'Ready',
      colorKey: 'amber',
      icon: Icons.flash_on_rounded,
    ),
    _DonutMeta(
      label: 'Complete',
      colorKey: 'teal',
      icon: Icons.task_alt_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _colorOf(String key) {
    switch (key) {
      case 'danger':
        return NovaColors.danger;
      case 'amber':
        return NovaColors.amber;
      case 'teal':
        return NovaColors.teal;
      default:
        return NovaColors.textSecondary;
    }
  }

  Color _bgColorOf(String key) {
    switch (key) {
      case 'danger':
        return NovaColors.dangerLight;
      case 'amber':
        return NovaColors.amberLight;
      case 'teal':
        return NovaColors.tealLight;
      default:
        return NovaColors.bgSecondary;
    }
  }

  List<int> _buildSectionToItemMap(List<int> values) {
    final map = <int>[];

    for (int i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        map.add(i);
      }
    }

    return map;
  }

  List<PieChartSectionData> _buildSections(
    List<int> values,
    int total,
    List<int> sectionToItem,
  ) {
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: NovaColors.bgSecondary,
          radius: widget.chartSize * 0.15,
          showTitle: false,
          borderSide: BorderSide.none,
        ),
      ];
    }

    return List.generate(sectionToItem.length, (sIdx) {
      final itemIdx = sectionToItem[sIdx];
      final isTouched = _touchedItemIndex == itemIdx;

      return PieChartSectionData(
        value: values[itemIdx].toDouble(),
        color: _colorOf(_items[itemIdx].colorKey),
        radius: widget.chartSize * (isTouched ? 0.177 : 0.15),
        showTitle: false,
        borderSide: const BorderSide(
          color: NovaColors.bgPrimary,
          width: 2.5,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: ReportService(widget.ownerId).getOrderStatusStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ??
            {
              'pending': 0,
              'ready': 0,
              'completed': 0,
            };

        final values = [
          stats['pending'] ?? 0,
          stats['ready'] ?? 0,
          stats['completed'] ?? 0,
        ];

        final total = values.fold(0, (s, v) => s + v);

        final sectionToItem = _buildSectionToItemMap(values);

        if (_touchedItemIndex != null && values[_touchedItemIndex!] == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _touchedItemIndex = null;
              });
            }
          });
        }

        return FadeTransition(
          opacity: _fadeAnim,
          child: widget.compact
              ? _CompactDonutCard(
                  total: total,
                  sections: _buildSections(values, total, sectionToItem),
                )
              : Container(
                  width: double.infinity,
                  height: widget.cardHeight,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: NovaColors.borderTertiary,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: NovaColors.violetLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.donut_large_rounded,
                              size: 15,
                              color: NovaColors.violet,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Order distribution',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: NovaColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: NovaColors.bgSecondary,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: NovaColors.borderTertiary,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '$total total',
                              style: const TextStyle(
                                fontSize: 11,
                                color: NovaColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: widget.chartSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sections: _buildSections(
                                      values,
                                      total,
                                      sectionToItem,
                                    ),
                                    centerSpaceRadius: widget.chartSize * 0.275,
                                    sectionsSpace: total == 0 ? 0 : 2.5,
                                    startDegreeOffset: -90,
                                    borderData: FlBorderData(show: false),
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, resp) {
                                        setState(() {
                                          if (!event
                                                  .isInterestedForInteractions ||
                                              resp == null ||
                                              resp.touchedSection == null) {
                                            _touchedItemIndex = null;
                                            return;
                                          }

                                          final sIdx = resp.touchedSection!
                                              .touchedSectionIndex;

                                          if (sIdx < 0 ||
                                              sIdx >= sectionToItem.length) {
                                            _touchedItemIndex = null;
                                            return;
                                          }

                                          final itemIdx = sectionToItem[sIdx];

                                          _touchedItemIndex =
                                              _touchedItemIndex == itemIdx
                                                  ? null
                                                  : itemIdx;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Column(
                                    key: UniqueKey(),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _touchedItemIndex != null && total > 0
                                            ? '${values[_touchedItemIndex!]}'
                                            : '$total',
                                        style: TextStyle(
                                          fontSize: widget.chartSize * 0.15,
                                          fontWeight: FontWeight.w700,
                                          color: NovaColors.textPrimary,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _touchedItemIndex != null && total > 0
                                            ? _items[_touchedItemIndex!]
                                                .label
                                                .toLowerCase()
                                            : 'orders',
                                        style: TextStyle(
                                          fontSize: widget.chartSize * 0.065,
                                          color: NovaColors.textTertiary,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_items.length, (i) {
                                final meta = _items[i];
                                final val = values[i];

                                final pct = total == 0
                                    ? 0
                                    : (val / total * 100).round();

                                final color = _colorOf(meta.colorKey);
                                final bgCol = _bgColorOf(meta.colorKey);

                                final active = _touchedItemIndex == i;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _touchedItemIndex = active ? null : i;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: EdgeInsets.only(
                                      bottom: i == _items.length - 1 ? 0 : 8,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? bgCol
                                          : NovaColors.bgSecondary,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: active
                                            ? color.withOpacity(0.35)
                                            : NovaColors.borderTertiary,
                                        width: active ? 1.0 : 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            meta.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: active
                                                  ? color
                                                  : NovaColors.textSecondary,
                                              fontWeight: active
                                                  ? FontWeight.w500
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$val',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: active
                                                ? color
                                                : NovaColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$pct%',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: NovaColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (widget.showSegmentBar && total > 0) ...[
                        const SizedBox(height: 12),
                        _SegmentBar(
                          values: values,
                          total: total,
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _CompactDonutCard extends StatelessWidget {
  final int total;
  final List<PieChartSectionData> sections;

  const _CompactDonutCard({
    required this.total,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: NovaColors.violetLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.donut_large_rounded,
              color: NovaColors.violet,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Breakdown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: NovaColors.textPrimary,
                  ),
                ),
                Text(
                  '$total total orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: NovaColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox.square(
            dimension: 38,
            child: PieChart(
              PieChartData(
                sections: sections
                    .map(
                      (section) => section.copyWith(
                        radius: 7,
                        borderSide: const BorderSide(
                          color: NovaColors.bgPrimary,
                          width: 1,
                        ),
                      ),
                    )
                    .toList(),
                centerSpaceRadius: 10,
                sectionsSpace: total == 0 ? 0 : 1,
                startDegreeOffset: -90,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  final List<int> values;
  final int total;

  const _SegmentBar({
    required this.values,
    required this.total,
  });

  static const _colors = [
    NovaColors.danger,
    NovaColors.amber,
    NovaColors.teal,
  ];

  static const _labels = [
    'Pending',
    'Ready',
    'Complete',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: Row(
              children: List.generate(values.length, (i) {
                if (values[i] == 0) {
                  return const SizedBox.shrink();
                }

                return Flexible(
                  flex: values[i],
                  child: Container(
                    color: _colors[i],
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(values.length, (i) {
            final pct = total == 0 ? 0 : (values[i] / total * 100).round();

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_labels[i]} $pct%',
                  style: const TextStyle(
                    fontSize: 10,
                    color: NovaColors.textTertiary,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _DonutMeta {
  final String label;
  final String colorKey;
  final IconData icon;

  const _DonutMeta({
    required this.label,
    required this.colorKey,
    required this.icon,
  });
}
