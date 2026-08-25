import 'dart:math';

import 'package:flutter/material.dart';

import '../core/design.dart';

/// Wordmark EKENGE PLUS — signature typographique de l'application.
class EkWordmark extends StatelessWidget {
  final double size;
  final bool showSub;
  final CrossAxisAlignment align;

  const EkWordmark({
    super.key,
    this.size = 16,
    this.showSub = false,
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'EKENGE',
                style: Ek.wordmark(size: size),
              ),
              TextSpan(
                text: '\u2009PLUS',
                style: Ek.wordmark(size: size, color: Ek.accent),
              ),
            ],
          ),
        ),
        if (showSub) ...[
          SizedBox(height: size * 0.42),
          Text('SECURITE PERSONNELLE', style: Ek.over(size: size * 0.52)),
        ],
      ],
    );
  }
}

/// Marque circulaire (icone d'application interne, splash, en-tetes).
class EkMark extends StatelessWidget {
  final double size;
  final Color color;
  const EkMark({super.key, this.size = 56, this.color = Ek.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Ek.surfaceHigh,
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
        boxShadow: Ek.glow(color, o: 0.18, b: 26),
      ),
      child: Center(
        child: Icon(Icons.shield_outlined, size: size * 0.46, color: color),
      ),
    );
  }
}

/// Etiquette de section en petites capitales espacees.
class EkSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const EkSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: Ek.over())),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Carte de surface premium avec filet 1px.
class EkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? border;
  final double radius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  const EkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.border,
    this.radius = Ek.r20,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Ek.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? Ek.hairline, width: 1),
        boxShadow: shadow,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: Ek.accent.withValues(alpha: 0.06),
        highlightColor: Ek.accent.withValues(alpha: 0.04),
        child: body,
      ),
    );
  }
}

/// Bouton primaire pleine largeur.
class EkButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool loading;
  final bool outlined;
  final double height;

  const EkButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = Ek.accent,
    this.textColor = const Color(0xFF04120F),
    this.loading = false,
    this.outlined = false,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = outlined ? Colors.transparent : color;
    final fg = outlined ? color : textColor;

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(Ek.r16),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(Ek.r16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Ek.r16),
                border: outlined
                    ? Border.all(
                        color: color.withValues(alpha: 0.6),
                        width: 1.3,
                      )
                    : null,
              ),
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(fg),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 18, color: fg),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            label.toUpperCase(),
                            style: Ek.over(size: 12, color: fg),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille d'etat (Tracking actif, Niveau 1, etc.).
class EkPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  const EkPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: solid ? 1 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: solid ? Colors.white : color),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: Ek.over(size: 9.5, color: solid ? Colors.white : color),
          ),
        ],
      ),
    );
  }
}

/// Point lumineux pulsant (etat actif).
class EkPulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const EkPulseDot({super.key, this.color = Ek.safe, this.size = 8});

  @override
  State<EkPulseDot> createState() => _EkPulseDotState();
}

class _EkPulseDotState extends State<EkPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return SizedBox(
          width: widget.size * 3,
          height: widget.size * 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + widget.size * 2 * t,
                height: widget.size + widget.size * 2 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: (1 - t) * 0.55),
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: Ek.glow(widget.color, o: 0.5, b: 8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Monogramme de contact (aucune photo, aucun visage).
class EkMonogram extends StatelessWidget {
  final String initials;
  final double size;
  final Color color;
  final bool linked;

  const EkMonogram({
    super.key,
    required this.initials,
    this.size = 42,
    this.color = Ek.accent,
    this.linked = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Ek.surfaceHigh,
        border: Border.all(
          color: linked ? color.withValues(alpha: 0.45) : Ek.hairline,
          width: 1.1,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: Ek.over(
            size: size * 0.32,
            color: linked ? color : Ek.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Anneau de progression fin.
class EkRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final Color color;
  final Widget? center;
  final double stroke;

  const EkRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.color = Ek.accent,
    this.center,
    this.stroke = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(progress.clamp(0, 1), color, stroke),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  final Color color;
  final double stroke;
  _RingPainter(this.p, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = rect.center;
    final r = size.width / 2 - stroke / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Ek.hairline;
    canvas.drawCircle(c, r, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.35), color],
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
      ).createShader(rect);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * p,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.p != p || o.color != color;
}

/// Champ de saisie premium avec libelle en capitales.
class EkField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboard;
  final bool obscure;
  final IconData? icon;
  final Widget? suffix;
  final String? error;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final TextCapitalization caps;
  final bool autofocus;

  const EkField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard = TextInputType.text,
    this.obscure = false,
    this.icon,
    this.suffix,
    this.error,
    this.onChanged,
    this.maxLength,
    this.caps = TextCapitalization.none,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label.toUpperCase(), style: Ek.over()),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          obscureText: obscure,
          autofocus: autofocus,
          maxLength: maxLength,
          textCapitalization: caps,
          onChanged: onChanged,
          style: Ek.body(size: 15.5, color: Ek.textPrimary),
          cursorColor: Ek.accent,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            errorText: error,
            errorStyle: Ek.body(size: 11.5, color: Ek.dangerBright),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 19, color: Ek.textTertiary),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// En-tete d'ecran secondaire.
class EkHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool back;

  const EkHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.back = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
      child: Row(
        children: [
          if (back)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: Ek.textSecondary,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ek.title(size: 19)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Ek.body(size: 12.5)),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Etat vide sobre.
class EkEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EkEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Ek.surface,
                border: Border.all(color: Ek.hairline),
              ),
              child: Icon(icon, color: Ek.textTertiary, size: 26),
            ),
            const SizedBox(height: 18),
            Text(title, style: Ek.title(size: 16)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Ek.body(size: 13),
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// Rangee cle / valeur avec filet.
class EkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  const EkRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor = Ek.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ek.r12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Ek.body(size: 14.5, color: Ek.textPrimary),
              ),
            ),
            if (value != null)
              Text(value!, style: Ek.body(size: 13.5, color: Ek.textSecondary)),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 18, color: Ek.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}

String ekFormatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }
  if (d.inMinutes > 0) {
    return '${d.inMinutes} min ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
  }
  return '${d.inSeconds}s';
}

String ekFormatClock(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$m:$s';
  return '$m:$s';
}

String ekFormatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String ekFormatDateTime(DateTime d) {
  const months = [
    'jan',
    'fev',
    'mar',
    'avr',
    'mai',
    'jui',
    'jul',
    'aou',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  return '${d.day} ${months[d.month - 1]} · ${ekFormatTime(d)}';
}

String ekRelative(DateTime d) {
  final s = DateTime.now().difference(d);
  if (s.inSeconds < 45) return 'a l\'instant';
  if (s.inMinutes < 60) return 'il y a ${s.inMinutes} min';
  if (s.inHours < 24) return 'il y a ${s.inHours} h';
  return ekFormatDateTime(d);
}
