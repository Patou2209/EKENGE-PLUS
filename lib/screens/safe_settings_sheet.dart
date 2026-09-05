import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design.dart';
import '../services/ek_state.dart';
import '../widgets/common.dart';

/// EKENGE PLUS — §8 Fonction Safe : definition de la frequence de verification.
/// Frequences possibles : 15, 30, 60 minutes ou frequence personnalisee.
class SafeSettingsSheet extends StatefulWidget {
  const SafeSettingsSheet({super.key});

  @override
  State<SafeSettingsSheet> createState() => _SafeSettingsSheetState();
}

class _SafeSettingsSheetState extends State<SafeSettingsSheet> {
  final _custom = TextEditingController();
  bool _customMode = false;

  @override
  void initState() {
    super.initState();
    final v = context.read<EkState>().safeIntervalMinutes;
    if (![15, 30, 60].contains(v)) {
      _customMode = true;
      _custom.text = '$v';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<EkState>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Ek.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Ek.accent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Ek.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      size: 19,
                      color: Ek.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vérification de sécurité',
                          style: Ek.title(size: 17),
                        ),
                        const SizedBox(height: 3),
                        Text('Fonction Safe', style: Ek.body(size: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: st.safeEnabled,
                    onChanged: (v) => st.setSafeEnabled(v),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Lorsque le Tracking est actif, l\'application déclenché une '
                'alarme sonore à chaque intervalle. Vous devez déverrouiller '
                'votre téléphone, ouvrir l\'application et appuyer sur '
                '« Je suis en sécurité ».',
                style: Ek.body(size: 12.5, height: 1.55),
              ),
              const SizedBox(height: 22),
              const EkSectionLabel('Fréquence de vérification'),
              Row(
                children: [
                  _FreqChip(
                    minutes: 15,
                    selected: !_customMode && st.safeIntervalMinutes == 15,
                    onTap: () => _select(15),
                  ),
                  const SizedBox(width: 10),
                  _FreqChip(
                    minutes: 30,
                    selected: !_customMode && st.safeIntervalMinutes == 30,
                    onTap: () => _select(30),
                  ),
                  const SizedBox(width: 10),
                  _FreqChip(
                    minutes: 60,
                    selected: !_customMode && st.safeIntervalMinutes == 60,
                    onTap: () => _select(60),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Frequence personnalisee
              InkWell(
                onTap: () => setState(() => _customMode = true),
                borderRadius: BorderRadius.circular(Ek.r16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _customMode
                        ? Ek.accent.withValues(alpha: 0.07)
                        : Ek.surface,
                    borderRadius: BorderRadius.circular(Ek.r16),
                    border: Border.all(
                      color: _customMode
                          ? Ek.accent.withValues(alpha: 0.45)
                          : Ek.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _customMode
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 17,
                        color: _customMode ? Ek.accent : Ek.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fréquence personnalisée',
                          style: Ek.body(size: 13.5, color: Ek.textPrimary),
                        ),
                      ),
                      if (_customMode)
                        SizedBox(
                          width: 92,
                          child: TextField(
                            controller: _custom,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: Ek.body(size: 14, color: Ek.textPrimary),
                            cursorColor: Ek.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'min',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: Ek.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Ek.hairline,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Ek.hairline,
                                ),
                              ),
                            ),
                            onSubmitted: (v) {
                              final m = int.tryParse(v);
                              if (m != null && m >= 1 && m <= 720) {
                                st.setSafeInterval(m);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_customMode) ...[
                const SizedBox(height: 8),
                Text('Entre 1 et 720 minutes', style: Ek.body(size: 11)),
              ],
              const SizedBox(height: 22),
              // Rappel du protocole d'escalade (§9)
              EkCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROTOCOLE D\'ESCALADE', style: Ek.over(size: 9.5)),
                    const SizedBox(height: 14),
                    _Escalation(
                      color: Ek.warn,
                      level: 'NIVEAU 1',
                      title: 'Alerte préventive',
                      text:
                          'Absence de confirmation : notification Push et '
                          'message WhatsApp à la liste Tracking, partage de la '
                          'dernière position connue, activation du suivi.',
                    ),
                    const Divider(height: 22),
                    _Escalation(
                      color: Ek.danger,
                      level: 'NIVEAU 2',
                      title: 'Alerte critique',
                      text:
                          'Quinze minutes après l\'alerte préventive sans '
                          'confirmation : notification Push et message WhatsApp '
                          'à la liste Urgence, géolocalisation temps réel '
                          'partagée, incident considéré comme critique.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Acceleration temporelle pour observer les cycles en preview.
              EkCard(
                padding: const EdgeInsets.all(16),
                color: Ek.surfaceHigh,
                child: Row(
                  children: [
                    const Icon(
                      Icons.speed_outlined,
                      size: 18,
                      color: Ek.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode démonstration',
                            style: Ek.body(size: 13, color: Ek.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Compresse les délais (1 minute = 1 seconde) afin '
                            'd\'observer les cycles Safe et l\'escalade.',
                            style: Ek.body(size: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: st.demoTimeScale,
                      onChanged: (v) => st.setDemoTimeScale(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              EkButton(
                label: 'Enregistrer',
                icon: Icons.check,
                onPressed: () {
                  if (_customMode) {
                    final m = int.tryParse(_custom.text);
                    if (m != null && m >= 1 && m <= 720) {
                      st.setSafeInterval(m);
                    }
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(int m) {
    setState(() => _customMode = false);
    context.read<EkState>().setSafeInterval(m);
  }
}

class _FreqChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;
  const _FreqChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ek.r16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? Ek.accent.withValues(alpha: 0.10) : Ek.surface,
            borderRadius: BorderRadius.circular(Ek.r16),
            border: Border.all(
              color: selected ? Ek.accent.withValues(alpha: 0.55) : Ek.hairline,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$minutes',
                style: Ek.num(
                  size: 20,
                  color: selected ? Ek.accent : Ek.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'MIN',
                style: Ek.over(
                  size: 8.5,
                  color: selected ? Ek.accent : Ek.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Escalation extends StatelessWidget {
  final Color color;
  final String level;
  final String title;
  final String text;

  const _Escalation({
    required this.color,
    required this.level,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(level, style: Ek.over(size: 9, color: color)),
                  const SizedBox(width: 8),
                  Text(title, style: Ek.body(size: 13, color: Ek.textPrimary)),
                ],
              ),
              const SizedBox(height: 6),
              Text(text, style: Ek.body(size: 11.5, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
