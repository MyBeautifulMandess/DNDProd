import 'package:flutter/material.dart';

import 'character_builder_controller.dart';
import 'steps/abilities_step.dart';
import 'steps/background_step.dart';
import 'steps/class_step.dart';
import 'steps/equipment_step.dart';
import 'steps/identity_step.dart';
import 'steps/race_step.dart';
import 'steps/spells_step.dart';

const Color _gold = Color(0xFFC9A227);

class CharacterBuilderScreen extends StatefulWidget {
  const CharacterBuilderScreen({super.key});

  @override
  State<CharacterBuilderScreen> createState() => _CharacterBuilderScreenState();
}

class _CharacterBuilderScreenState extends State<CharacterBuilderScreen> {
  late final CharacterBuilderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CharacterBuilderController();
    _controller.addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Создание персонажа — ${_controller.currentStep.titleRu}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            Expanded(child: _buildStepBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProgress() {
    final total = BuilderStep.values.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= _controller.stepIndex
                        ? _gold
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                if (i < total - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < _controller.stepIndex
                          ? _gold
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Шаг ${_controller.stepIndex + 1} из $total',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Не удалось загрузить каталог.\n${_controller.loadError}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final Widget step;
    switch (_controller.currentStep) {
      case BuilderStep.race:
        step = RaceStep(controller: _controller);
        break;
      case BuilderStep.classStep:
        step = ClassStep(controller: _controller);
        break;
      case BuilderStep.abilities:
        step = AbilitiesStep(controller: _controller);
        break;
      case BuilderStep.background:
        step = BackgroundStep(controller: _controller);
        break;
      case BuilderStep.equipment:
        step = EquipmentStep(controller: _controller);
        break;
      case BuilderStep.spells:
        step = SpellsStep(controller: _controller);
        break;
      case BuilderStep.identity:
        step = IdentityStep(controller: _controller);
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: step,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isReady = !_controller.isLoading && _controller.loadError == null;
    final canProceed = isReady && _controller.isCurrentStepValid;
    final isLast = _controller.isLastStep;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: !isReady || _controller.stepIndex == 0
                    ? null
                    : _controller.previousStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Назад'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: !canProceed
                    ? null
                    : () {
                        if (isLast) {
                          _saveAndClose();
                        } else {
                          _controller.nextStep();
                        }
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                ),
                child: Text(isLast ? 'Сохранить' : 'Далее'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndClose() async {
    final saved = await _controller.save();
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.saveError == null
                ? 'Не удалось сохранить персонажа'
                : 'Не удалось сохранить персонажа: ${_controller.saveError}',
          ),
        ),
      );
    }
  }
}
