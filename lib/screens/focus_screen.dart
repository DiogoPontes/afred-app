// lib/screens/focus_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemSound
// Se quiser usar áudio mais avançado, descomente e adicione audioplayers no pubspec:
// import 'package:audioplayers/audioplayers.dart';

class FocusScreen extends StatefulWidget {
  final String taskTitle;
  final bool demoMode; // se true usa segundos para facilitar testes
  final void Function(String summary)? onSaveSummary; // callback quando o usuário clica em "Resumo"
  final VoidCallback? onMarkDone; // callback quando marca como concluída

  const FocusScreen({
    Key? key,
    required this.taskTitle,
    this.demoMode = false,
    this.onSaveSummary,
    this.onMarkDone,
  }) : super(key: key);

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with TickerProviderStateMixin {
  // Durations (em segundos quando demoMode == true, senão em segundos padrão convertidos)
  late int focusSec;
  late int shortBreakSec;
  late int longBreakSec;
  int cyclesToLong = 4;

  // Estado do cronômetro
  String phase = 'focus'; // 'focus' | 'short' | 'long'
  late int totalForPhase; // segundos total do passo atual
  late int remaining; // segundos restantes
  bool running = false;
  Timer? _timer;

  // progresso e gamificação
  int completedCycles = 0;
  int rewards = 0;

  // UI
  bool soundOn = false;
  String preset = 'demo'; // demo | pomodoro | short

  @override
  void initState() {
    super.initState();
    _applyPreset(widget.demoMode ? 'demo' : 'pomodoro');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _applyPreset(String p) {
    setState(() {
      preset = p;
      if (p == 'demo') {
        focusSec = 25; // 25s para demo
        shortBreakSec = 5;
        longBreakSec = 15;
      } else if (p == 'pomodoro') {
        focusSec = 25 * 60;
        shortBreakSec = 5 * 60;
        longBreakSec = 15 * 60;
      } else if (p == 'short') {
        focusSec = 15 * 60;
        shortBreakSec = 5 * 60;
        longBreakSec = 10 * 60;
      }
      phase = 'focus';
      totalForPhase = focusSec;
      remaining = totalForPhase;
      running = false;
      _timer?.cancel();
    });
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return (s >= 60) ? '$m:$sec' : '00:$sec';
  }

  double _progressValue() {
    if (totalForPhase <= 0) return 0.0;
    return 1.0 - (remaining / totalForPhase);
  }

  void _startPause() {
    if (running) {
      _stopTicker();
    } else {
      _startTicker();
    }
  }

  void _startTicker() {
    if (remaining <= 0) remaining = totalForPhase;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (remaining > 0) {
          remaining -= 1;
        } else {
          _timer?.cancel();
          _onPhaseEnd();
        }
      });
    });
    setState(() {
      running = true;
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    setState(() {
      running = false;
    });
  }

  void _resetTimer() {
    _stopTicker();
    setState(() {
      totalForPhase = (phase == 'focus')
          ? focusSec
          : (phase == 'short' ? shortBreakSec : longBreakSec);
      remaining = totalForPhase;
    });
  }

  void _skip() {
    _stopTicker();
    _onPhaseEnd(skipped: true);
  }

  void _onPhaseEnd({bool skipped = false}) {
    // beep or simple sound
    if (soundOn) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      // Se usar audioplayers, tocaria um arquivo local ou asset aqui.
    }

    setState(() {
      if (phase == 'focus') {
        completedCycles += 1;
        rewards += 1; // recompensa por terminar foco
        // decidir próxima fase
        if (completedCycles % cyclesToLong == 0) {
          phase = 'long';
          totalForPhase = longBreakSec;
        } else {
          phase = 'short';
          totalForPhase = shortBreakSec;
        }
      } else {
        phase = 'focus';
        totalForPhase = focusSec;
      }
      remaining = totalForPhase;
      running = false;
    });
  }

  void _markDone() {
    // Aciona callback para permitir ao app marcar no Hive/outro local
    setState(() {
      rewards += 2; // bônus por marcar manualmente
    });
    widget.onMarkDone?.call();
    // opcional: fechar tela após marcar
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefa marcada como concluída')));
  }

  void _saveSummary() {
    final summary = 'Concluí $completedCycles ciclos e ganhei $rewards pontos com a tarefa: "${widget.taskTitle}".';
    widget.onSaveSummary?.call(summary);
    // padrão: mostrar um snack
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resumo salvo/enviado')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = MaterialLocalizations.of(context).formatShortMonthDay(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Modo Foco'),
          Text(dateLabel, style: theme.textTheme.bodySmall),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(child: Text('$completedCycles / $cyclesToLong', style: const TextStyle(fontWeight: FontWeight.w600))),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              // Título da tarefa
              Text(widget.taskTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),

              // Card com timer
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor, width: 0.5),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Circulo de progresso + tempo
                    SizedBox(
                      height: 220,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: CircularProgressIndicator(
                                value: _progressValue().clamp(0.0, 1.0),
                                strokeWidth: 10,
                                backgroundColor: theme.dividerColor,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_formatTime(remaining), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(phase == 'focus' ? 'Foco' : (phase == 'short' ? 'Pausa curta' : 'Pausa longa'),
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // controles
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _startPause,
                          child: Text(running ? 'Pausar' : 'Iniciar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _skip, child: const Text('Pular')),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _resetTimer, child: const Text('Reset')),
                      ],
                    ),

                    const SizedBox(height: 8),
                    // Alfred + dots + rewards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: theme.canvasColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.dividerColor, width: 0.5),
                              ),
                              child: const Center(child: Text('🤵‍♂️', style: TextStyle(fontSize: 22))),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Alfred', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('Apoia sua sessão', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // dots
                            Row(
                              children: List.generate(cyclesToLong, (i) {
                                final active = i < completedCycles;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: active ? Colors.green : theme.dividerColor,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            Text('Recompensas: $rewards ✨', style: theme.textTheme.bodySmall),
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 12),

                    // opções: som / preset
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Switch(
                                value: soundOn,
                                onChanged: (v) => setState(() => soundOn = v),
                              ),
                              const SizedBox(width: 6),
                              const Text('Som ambiente'),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: preset,
                          items: const [
                            DropdownMenuItem(value: 'demo', child: Text('Demonstração (25s)')),
                            DropdownMenuItem(value: 'pomodoro', child: Text('Pomodoro (25m)')),
                            DropdownMenuItem(value: 'short', child: Text('Foco curto (15m)')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            _applyPreset(v);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Ações finais
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _markDone,
                            child: const Text('Marcar como concluído'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveSummary,
                            child: const Text('Resumo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}