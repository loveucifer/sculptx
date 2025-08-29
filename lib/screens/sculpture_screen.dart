import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../painters/custom_shape_painter.dart';

class ShapePresets {
  static List<vector.Vector3> get square => [
        vector.Vector3(-0.5, -0.5, 0),
        vector.Vector3(0.5, -0.5, 0),
        vector.Vector3(0.5, 0.5, 0),
        vector.Vector3(-0.5, 0.5, 0),
        vector.Vector3(-0.5, -0.5, 0),
      ];

  static List<vector.Vector3> get triangle => [
        vector.Vector3(0.0, -0.6, 0),
        vector.Vector3(0.7, 0.5, 0),
        vector.Vector3(-0.7, 0.5, 0),
        vector.Vector3(0.0, -0.6, 0),
      ];

  static List<vector.Vector3> get star => [
        vector.Vector3(0, -0.7, 0),
        vector.Vector3(0.2, -0.2, 0),
        vector.Vector3(0.8, -0.2, 0),
        vector.Vector3(0.3, 0.2, 0),
        vector.Vector3(0.5, 0.8, 0),
        vector.Vector3(0, 0.5, 0),
        vector.Vector3(-0.5, 0.8, 0),
        vector.Vector3(-0.3, 0.2, 0),
        vector.Vector3(-0.8, -0.2, 0),
        vector.Vector3(-0.2, -0.2, 0),
        vector.Vector3(0, -0.7, 0),
      ];

  static List<vector.Vector3> get wave => _generateProceduralShape(100, (i, p) {
        final x = -0.8 + (i / p) * 1.6;
        final y = math.sin(x * math.pi * 2) * 0.4;
        return vector.Vector3(x, y, 0);
      });

  static List<vector.Vector3> get spiral =>
      _generateProceduralShape(200, (i, p) {
        final angle = i / 20;
        final radius = (i / p) * 0.8;
        return vector.Vector3(
            math.cos(angle) * radius, math.sin(angle) * radius, 0);
      });

  static List<vector.Vector3> get torusKnot =>
      _generateProceduralShape(300, (i, p) {
        const q = 2.0;
        const p_ = 3.0;
        final angle = (i / p) * 2 * math.pi;
        final r = math.cos(q * angle) + 2;
        final x = r * math.cos(p_ * angle) * 0.3;
        final y = r * math.sin(p_ * angle) * 0.3;
        return vector.Vector3(x, y, 0);
      });

  static List<vector.Vector3> get lissajous =>
      _generateProceduralShape(300, (i, p) {
        const a = 3.0;
        const b = 2.0;
        const delta = math.pi / 2;
        final t = (i / p) * 2 * math.pi;
        final x = math.sin(a * t + delta) * 0.7;
        final y = math.sin(b * t) * 0.7;
        return vector.Vector3(x, y, 0);
      });

  static List<vector.Vector3> _generateProceduralShape(
      int points, vector.Vector3 Function(double, double) formula) {
    final list = <vector.Vector3>[];
    for (int i = 0; i <= points; i++) {
      list.add(formula(i.toDouble(), points.toDouble()));
    }
    return list;
  }
}

class SculptureScreen extends StatefulWidget {
  const SculptureScreen({super.key});

  @override
  State<SculptureScreen> createState() => _SculptureScreenState();
}

class _SculptureScreenState extends State<SculptureScreen>
    with TickerProviderStateMixin {
  // Transformation state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _scale = 1.0;
  Offset _lastPanUpdate = Offset.zero;

  // Shape and drawing state
  List<vector.Vector3> _points = [];
  bool _isDrawingMode = false;
  bool _isDragging = false;

  // Shape manipulation state with proper range
  double _extrusion = 0.5;
  double _twist = 0.0;

  // Sound generation state
  bool _isPlaying = false;
  SoundHandle? _soundHandle;
  AudioSource? _audioSource;
  WaveForm _waveform = WaveForm.saw;

  // Animation controllers for reactive sound
  late AnimationController _soundAnimationController;
  double _currentFrequency = 440.0;
  double _targetFrequency = 440.0;

  // UI state
  bool _isControlPanelExpanded = false;
  late AnimationController _panelAnimationController;
  bool _showGestureHints = true;
  Timer? _hintTimer;

  // Gesture state
  bool _isScaling = false;
  bool _isTwoFingerDrag = false;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _soundAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _soundAnimationController.addListener(_updateSoundParameters);

    SoLoud.instance.init().then((_) {
      // Load initial shape which will also trigger hints
      _loadPreset(ShapePresets.square);
    });
  }

  @override
  void dispose() {
    _stopSound();
    _soundAnimationController.dispose();
    _panelAnimationController.dispose();
    _hintTimer?.cancel();
    SoLoud.instance.deinit();
    super.dispose();
  }

  void _showHintsTemporarily() {
    _hintTimer?.cancel();
    if (mounted) {
      setState(() {
        _showGestureHints = true;
      });
    }
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showGestureHints = false;
        });
      }
    });
  }

  void _stopSound() {
    if (_soundHandle != null) SoLoud.instance.stop(_soundHandle!);
    if (_audioSource != null) SoLoud.instance.disposeSource(_audioSource!);
    setState(() {
      _isPlaying = false;
      _soundHandle = null;
      _audioSource = null;
    });
  }

  void _updateSoundParameters() {
    if (_audioSource != null && _isPlaying) {
      final currentFreq = _calculateShapeFrequency();
      final currentVol = _calculateShapeVolume();

      SoLoud.instance.setWaveformFreq(_audioSource!, currentFreq);
      if (_soundHandle != null) {
        SoLoud.instance.setVolume(_soundHandle!, currentVol);
      }
    }
  }

  double _calculateShapeFrequency() {
    if (_points.length < 2) return 220.0;

    double complexity = _points.length.toDouble();
    double extrusionFactor = _extrusion;
    double twistFactor = _twist.abs();
    double scaleFactor = _scale;

    // Calculate perimeter-based frequency
    double totalLength = 0;
    for (int i = 0; i < _points.length - 1; i++) {
      totalLength += _points[i].distanceTo(_points[i + 1]);
    }

    // Combine multiple shape properties for frequency
    double baseFreq = 80.0 + (complexity * 8);
    baseFreq += (totalLength * 50);
    baseFreq += (extrusionFactor * 100);
    baseFreq += (twistFactor * 80);
    baseFreq *= scaleFactor;

    return baseFreq.clamp(60.0, 2000.0);
  }

  double _calculateShapeVolume() {
    if (_points.length < 2) return 0.3;

    double totalLength = 0;
    for (int i = 0; i < _points.length - 1; i++) {
      totalLength += _points[i].distanceTo(_points[i + 1]);
    }

    double volume = (totalLength / 10).clamp(0.1, 1.0);
    volume *= _scale.clamp(0.5, 1.5);
    volume *= (1.0 + _extrusion * 0.3);

    return volume;
  }

  Future<void> _playSoundFromShape() async {
    if (_points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or draw a shape to synthesize.')),
      );
      return;
    }

    if (_isPlaying) {
      _stopSound();
      return;
    }

    try {
      _audioSource =
          await SoLoud.instance.loadWaveform(_waveform, true, 1.0, 0.0);

      if (_audioSource != null) {
        final frequency = _calculateShapeFrequency();
        final volume = _calculateShapeVolume();

        SoLoud.instance.setWaveformFreq(_audioSource!, frequency);
        final handle = await SoLoud.instance
            .play(_audioSource!, volume: volume, looping: true);

        setState(() {
          _isPlaying = true;
          _soundHandle = handle;
          _currentFrequency = frequency;
          _targetFrequency = frequency;
        });
      }
    } catch (e) {
      print('Error playing sound: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio error: $e')),
      );
    }
  }

  void _onShapeParameterChanged() {
    if (_isPlaying) {
      _updateSoundParameters();
    }
  }

  void _clearDrawing() {
    _stopSound();
    setState(() {
      _points = [];
      _isDrawingMode = true;
    });
  }

  void _loadPreset(List<vector.Vector3> presetPoints) {
    _stopSound();
    setState(() {
      _points = List.from(presetPoints);
      _isDrawingMode = false;
    });
    _showHintsTemporarily();
  }

  void _addPointFromGesture(Offset localPosition, Size canvasSize) {
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    final scale = canvasSize.width *
        0.4; // Adjusted for better sensitivity as u require i liked this so i did this

    final x = (localPosition.dx - centerX) / scale;
    final y = (localPosition.dy - centerY) / scale;

    setState(() {
      _points.add(vector.Vector3(x, y, 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCULPTX V-1.0'),
        centerTitle: false,
        backgroundColor: Colors.black87,
        foregroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(_isControlPanelExpanded
                ? Icons.expand_more
                : Icons.expand_less),
            onPressed: () {
              setState(() {
                _isControlPanelExpanded = !_isControlPanelExpanded;
              });
              if (_isControlPanelExpanded) {
                _panelAnimationController.forward();
              } else {
                _panelAnimationController.reverse();
              }
            },
            tooltip:
                _isControlPanelExpanded ? 'Hide Controls' : 'Show Controls',
          ),
          // Quick action buttons always visible
          IconButton(
            icon: Icon(_isDrawingMode ? Icons.edit : Icons.edit_off_outlined),
            color: _isDrawingMode
                ? Theme.of(context).primaryColor
                : Colors.grey[600],
            onPressed: () {
              setState(() {
                _isDrawingMode = !_isDrawingMode;
                if (_isDrawingMode) _clearDrawing();
              });
            },
            tooltip: _isDrawingMode ? 'Exit Drawing' : 'Draw Shape',
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            color: _isPlaying ? Colors.red : Theme.of(context).primaryColor,
            onPressed: _playSoundFromShape,
            tooltip: _isPlaying ? 'Stop Sound' : 'Play Sound',
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main canvas are
          Positioned.fill(
            bottom: _isControlPanelExpanded ? 350 : 60,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize =
                    Size(constraints.maxWidth, constraints.maxHeight);

                return GestureDetector(
                  onScaleStart: (details) {
                    _lastPanUpdate = details.localFocalPoint;
                    _isDragging = false;
                    _baseScale = _scale;
                    _isScaling = details.pointerCount > 1;
                    _isTwoFingerDrag = details.pointerCount == 2;

                    if (_isDrawingMode && details.pointerCount == 1) {
                      _points.clear();
                      _addPointFromGesture(details.localFocalPoint, canvasSize);
                    }
                  },
                  onScaleUpdate: (details) {
                    if (_isDrawingMode && details.pointerCount == 1) {
                      _addPointFromGesture(details.localFocalPoint, canvasSize);
                      _isDragging = true;
                    } else if (details.pointerCount == 2) {
                      // Two finger gestures
                      final delta = details.localFocalPoint - _lastPanUpdate;

                      setState(() {
                        // Scale with pinch
                        _scale = (_baseScale * details.scale).clamp(0.3, 3.0);

                        // Pan to move shape around
                        if (_isTwoFingerDrag) {
                          _rotationY += delta.dx * 0.005;
                          _rotationX += delta.dy * 0.005;
                        }
                      });
                      _onShapeParameterChanged();
                    } else if (details.pointerCount == 1 && !_isDrawingMode) {
                      // Single finger rotation
                      final delta = details.localFocalPoint - _lastPanUpdate;
                      setState(() {
                        _rotationY += delta.dx * 0.008;
                        _rotationX += delta.dy * 0.008;
                      });
                    }
                    _lastPanUpdate = details.localFocalPoint;
                  },
                  onScaleEnd: (details) {
                    if (_isDrawingMode && _isDragging) {
                      if (_points.length > 2) {
                        _points.add(_points.first);
                      }
                      setState(() {});
                    }
                    _isScaling = false;
                    _isTwoFingerDrag = false;
                  },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: CustomShapePainter(
                            points: _points,
                            rotationX: _rotationX,
                            rotationY: _rotationY,
                            scale: _scale,
                            extrusion: _extrusion,
                            twist: _twist,
                            color: Theme.of(context).primaryColor,
                          ),
                          size: Size.infinite,
                        ),
                        // Gesture hints overlay
                        Positioned(
                          top: 20,
                          left: 20,
                          child: AnimatedOpacity(
                            opacity: _showGestureHints &&
                                    !_isDrawingMode &&
                                    _points.isNotEmpty
                                ? 1.0
                                : 0.0,
                            duration: const Duration(milliseconds: 500),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('🖱️ Drag: Rotate',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12)),
                                  Text('🤏 Pinch: Scale',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12)),
                                  Text('✌️ Two fingers: Pan + Scale',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_isDrawingMode)
                          Positioned(
                            top: 20,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 1),
                              ),
                              child: Text(
                                '✏️ Drawing Mode - Drag to draw',
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Floating control panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: 0,
            left: 0,
            right: 0,
            height: _isControlPanelExpanded ? 350 : 60,
            child: _buildFloatingControlPanel(),
          ),

          // Quick manipulation controls
          if (!_isDrawingMode && _points.isNotEmpty)
            Positioned(
              right: 20,
              top: 100,
              child: _buildQuickControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Quick status bar (always visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isDrawingMode
                      ? 'DRAWING MODE'
                      : 'SHAPE: ${_points.length} points',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isPlaying)
                  Text(
                    '${_calculateShapeFrequency().toInt()}Hz',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),

          // Expandable content
          if (_isControlPanelExpanded)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPresetSelector(),
                    const SizedBox(height: 16),
                    _buildShapeManipulationSliders(),
                    const SizedBox(height: 16),
                    _buildWaveformSelector(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickControls() {
    return Column(
      children: [
        // Quick extrusion control
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Column(
            children: [
              Text('EXT',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10)),
              SizedBox(
                height: 100,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: Theme.of(context).primaryColor,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _extrusion,
                      min: 0.1,
                      max: 2.0,
                      onChanged: (val) {
                        setState(() => _extrusion = val);
                        _onShapeParameterChanged();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick twist control
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Column(
            children: [
              Text('TWIST',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10)),
              SizedBox(
                height: 100,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: Theme.of(context).primaryColor,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _twist,
                      min: -math.pi,
                      max: math.pi,
                      onChanged: (val) {
                        setState(() => _twist = val);
                        _onShapeParameterChanged();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Reset button
        FloatingActionButton.small(
          onPressed: () {
            setState(() {
              _rotationX = 0.0;
              _rotationY = 0.0;
              _scale = 1.0;
              _extrusion = 0.5;
              _twist = 0.0;
            });
            _onShapeParameterChanged();
          },
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.grey[400],
          child: const Icon(Icons.refresh, size: 16),
        ),
      ],
    );
  }

  Widget _buildPresetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PRESETS',
                style: TextStyle(
                    color: Colors.grey[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            IconButton(
              icon: Icon(
                _isDrawingMode ? Icons.edit : Icons.edit_off_outlined,
                color: _isDrawingMode
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
                size: 24,
              ),
              onPressed: () {
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                  if (_isDrawingMode) _clearDrawing();
                });
              },
              tooltip:
                  _isDrawingMode ? 'Exit Drawing Mode' : 'Enter Drawing Mode',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          children: [
            _buildPresetButton(
                Icons.square_outlined, ShapePresets.square, 'Square'),
            _buildPresetButton(Icons.change_history_rounded,
                ShapePresets.triangle, 'Triangle'),
            _buildPresetButton(
                Icons.star_outline_rounded, ShapePresets.star, 'Star'),
            _buildPresetButton(Icons.waves_rounded, ShapePresets.wave, 'Wave'),
            _buildPresetButton(
                Icons.circle_outlined, ShapePresets.spiral, 'Spiral'),
            _buildPresetButton(
                Icons.hub_outlined, ShapePresets.torusKnot, 'Torus'),
            _buildPresetButton(
                Icons.timeline, ShapePresets.lissajous, 'Lissajous'),
          ],
        ),
      ],
    );
  }

  Widget _buildShapeManipulationSliders() {
    return Column(
      children: [
        _buildSliderRow('EXTRUSION', _extrusion, 0.1, 2.0, (val) {
          setState(() => _extrusion = val);
          _onShapeParameterChanged();
        }),
        _buildSliderRow('TWIST', _twist, -math.pi, math.pi, (val) {
          setState(() => _twist = val);
          _onShapeParameterChanged();
        }),
        _buildSliderRow('SCALE', _scale, 0.5, 2.5, (val) {
          setState(() => _scale = val);
          _onShapeParameterChanged();
        }),
      ],
    );
  }

  Widget _buildWaveformSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WAVEFORM',
            style: TextStyle(
                color: Colors.grey[300],
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildWaveformButton(WaveForm.sin, 'SINE')),
            Expanded(child: _buildWaveformButton(WaveForm.triangle, 'TRI')),
            Expanded(child: _buildWaveformButton(WaveForm.saw, 'SAW')),
            Expanded(child: _buildWaveformButton(WaveForm.square, 'SQR')),
          ],
        ),
      ],
    );
  }

  Widget _buildWaveformButton(WaveForm form, String label) {
    final isSelected = _waveform == form;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: ElevatedButton(
        onPressed: () async {
          setState(() => _waveform = form);
          if (_isPlaying) {
            // Reload audio source with new waveform
            _stopSound();
            await Future.delayed(const Duration(milliseconds: 100));
            _playSoundFromShape();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
          foregroundColor: isSelected ? Colors.black : Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPresetButton(
      IconData icon, List<vector.Vector3> preset, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: Colors.grey[400], size: 22),
        onPressed: () => _loadPreset(preset),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Theme.of(context).primaryColor,
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              value.toStringAsFixed(2),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
