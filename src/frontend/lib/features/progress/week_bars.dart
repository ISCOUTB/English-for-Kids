import 'package:flutter/material.dart';

import 'progress_models.dart';

const List<String> _dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Barras de los últimos días: la parte oscura son los aciertos y la clara
/// los intentos que no salieron. Sin paquetes de gráficos.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.days, this.maxBarHeight = 96});

  final List<DayStats> days;
  final double maxBarHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final biggest = days.fold<int>(0, (m, d) => d.intentos > m ? d.intentos : m);
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: _Bar(
              day: day,
              biggest: biggest,
              maxBarHeight: maxBarHeight,
              isToday: day.fecha.year == today.year &&
                  day.fecha.month == today.month &&
                  day.fecha.day == today.day,
              strong: scheme.primary,
              soft: scheme.primaryContainer,
              textStyle: theme.textTheme.labelMedium,
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.biggest,
    required this.maxBarHeight,
    required this.isToday,
    required this.strong,
    required this.soft,
    required this.textStyle,
  });

  final DayStats day;
  final int biggest;
  final double maxBarHeight;
  final bool isToday;
  final Color strong;
  final Color soft;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final hasData = day.intentos > 0 && biggest > 0;
    final double total = hasData
        ? (day.intentos / biggest * maxBarHeight).clamp(10.0, maxBarHeight).toDouble()
        : 6.0;
    final double good = hasData ? total * (day.aciertos / day.intentos) : 0.0;
    final letter = _dayLetters[(day.fecha.weekday - 1) % 7];

    return Semantics(
      label: '$letter: ${day.aciertos} aciertos de ${day.intentos} intentos',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 18,
            child: Text(
              hasData ? '${day.intentos}' : '',
              style: textStyle?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: 26,
            height: total,
            decoration: BoxDecoration(
              color: hasData ? soft : const Color(0xFFEADFCB),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 26,
              height: good,
              decoration: BoxDecoration(
                color: strong,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isToday ? strong : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              letter,
              style: textStyle?.copyWith(
                fontWeight: FontWeight.w800,
                color: isToday ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
