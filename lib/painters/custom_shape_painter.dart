import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;

class CustomShapePainter extends CustomPainter {
  final List<vector.Vector3> points;
  final double rotationX;
  final double rotationY;
  final double scale;
  final double extrusion;
  final double twist;
  final Color color;
  final bool isInteracting;
  final double animationProgress;
  final bool showDebugInfo;

  CustomShapePainter({
    required this.points,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.extrusion,
    required this.twist,
    required this.color,
    this.isInteracting = false,
    this.animationProgress = 1.0,
    this.showDebugInfo = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final baseScale = math.min(size.width, size.height) * 0.3;

    // Enhanced lighting system
    final lightDirection = vector.Vector3(
      math.sin(rotationY) * math.cos(rotationX),
      math.sin(rotationX),
      math.cos(rotationY) * math.cos(rotationX),
    ).normalized();

    final ambientLight = 0.25;
    final diffuseStrength = 0.8;

    // Project points with enhanced effects
    final projectionResult = _projectPointsAdvanced(
      points,
      center,
      baseScale,
      lightDirection,
    );

    final frontPoints = projectionResult['front'] as List<Offset>;
    final backPoints = projectionResult['back'] as List<Offset>;
    final depths = projectionResult['depths'] as List<double>;
    final normals = projectionResult['normals'] as List<vector.Vector3>;

    // Calculate dynamic lighting
    final lightingValues = _calculateLighting(
        normals, lightDirection, ambientLight, diffuseStrength);

    //  paint configurations
    final paintConfig = _createPaintConfiguration(lightingValues);

    // Draw with proper depth sorting
    _drawBackgroundEffects(canvas, size, center);
    _drawShape(canvas, frontPoints, backPoints, depths, paintConfig);
    _drawInteractionFeedback(canvas, size, center);

    if (showDebugInfo) {
      _drawDebugInfo(canvas, size, frontPoints, backPoints, depths);
    }
  }

  Map<String, dynamic> _projectPointsAdvanced(
    List<vector.Vector3> inputPoints,
    Offset center,
    double baseScale,
    vector.Vector3 lightDir,
  ) {
    final frontPoints = <Offset>[];
    final backPoints = <Offset>[];
    final depths = <double>[];
    final normals = <vector.Vector3>[];

    // Enhanced rotation matrices for precsisionn
    final rotMatX = vector.Matrix4.rotationX(rotationX * animationProgress);
    final rotMatY = vector.Matrix4.rotationY(rotationY * animationProgress);
    final rotMatZ = vector.Matrix4.rotationZ(twist * 0.1);
    final combinedRotation = rotMatY * rotMatX * rotMatZ;

    // Dynamic extrusion with subtle animation
    final dynamicExtrusion =
        extrusion * (1.0 + math.sin(animationProgress * math.pi * 2) * 0.05);

    for (var i = 0; i < inputPoints.length; i++) {
      // Process front face
      var frontPoint = inputPoints[i].clone();
      frontPoint = _applyTransformations(frontPoint, i, inputPoints.length,
          combinedRotation, dynamicExtrusion * 0.5, false);

      // Process back face with twist
      var backPoint = inputPoints[i].clone();
      backPoint = _applyTransformations(backPoint, i, inputPoints.length,
          combinedRotation, -dynamicExtrusion * 0.5, true);

      // Enhanced perspective projection
      final frontProjected = _perspectiveProject(frontPoint, center, baseScale);
      final backProjected = _perspectiveProject(backPoint, center, baseScale);

      frontPoints.add(frontProjected.offset);
      backPoints.add(backProjected.offset);
      depths.add(frontProjected.depth);

      // Calculate surface normals for lighting
      if (i < inputPoints.length - 1) {
        final nextPoint = inputPoints[(i + 1) % inputPoints.length];
        final edge1 = nextPoint - inputPoints[i];
        final edge2 = vector.Vector3(0, 0, dynamicExtrusion);
        final normal = edge1.cross(edge2).normalized();
        normals.add(combinedRotation.transform3(normal));
      } else {
        normals.add(vector.Vector3(0, 0, 1));
      }
    }

    return {
      'front': frontPoints,
      'back': backPoints,
      'depths': depths,
      'normals': normals,
    };
  }

  vector.Vector3 _applyTransformations(
    vector.Vector3 point,
    int index,
    int totalPoints,
    vector.Matrix4 rotation,
    double zOffset,
    bool isBackFace,
  ) {
    // Progressive twist for back face
    if (twist != 0.0 && isBackFace) {
      final twistProgress = index / math.max(1, totalPoints - 1);
      final localTwist = twistProgress * twist * animationProgress;
      final twistMatrix = vector.Matrix4.rotationZ(localTwist);
      point = twistMatrix.transform3(point);
    }

    // Subtle breathing effect
    final breathingFactor =
        1.0 + math.sin(animationProgress * math.pi * 4) * 0.015;
    point *= breathingFactor;

    // Apply extrusion
    point.z += zOffset;

    // Apply rotation
    point = rotation.transform3(point);

    // Apply scale with interaction feedback
    final interactionScale = isInteracting ? 1.08 : 1.0;
    point *= scale * interactionScale;

    return point;
  }

  ({Offset offset, double depth}) _perspectiveProject(
    vector.Vector3 point,
    Offset center,
    double baseScale,
  ) {
    // Enhanced perspective with dynamic FOV
    final fov = 55.0 + (isInteracting ? 8.0 : 0.0);
    final perspectiveFactor = 1.0 / math.tan((fov * math.pi / 180) / 2);
    final near = 0.1;
    final far = 12.0;

    final z = math.max(near, perspectiveFactor - point.z * 0.15);
    final projectionScale = perspectiveFactor / z;

    final x = point.x * baseScale * projectionScale + center.dx;
    final y = point.y * baseScale * projectionScale + center.dy;

    final normalizedDepth = (point.z - near) / (far - near);

    return (offset: Offset(x, y), depth: normalizedDepth);
  }

  List<double> _calculateLighting(
    List<vector.Vector3> normals,
    vector.Vector3 lightDir,
    double ambient,
    double diffuse,
  ) {
    return normals.map((normal) {
      final dotProduct = normal.dot(lightDir).clamp(0.0, 1.0);
      return ambient + diffuse * dotProduct;
    }).toList();
  }

  Map<String, Paint> _createPaintConfiguration(List<double> lightingValues) {
    final avgLighting = lightingValues.isEmpty
        ? 0.7
        : lightingValues.reduce((a, b) => a + b) / lightingValues.length;

    final baseOpacity = (0.85 * avgLighting).clamp(0.3, 1.0);
    final interactionBoost = isInteracting ? 0.25 : 0.0;

    return {
      'backFace': Paint()
        ..color = color.withOpacity(0.12 + interactionBoost * 0.08)
        ..strokeWidth = 1.2 + (isInteracting ? 0.6 : 0.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      'connections': Paint()
        ..color =
            color.withOpacity(0.35 * avgLighting + interactionBoost * 0.15)
        ..strokeWidth = 0.8 + (isInteracting ? 0.4 : 0.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      'frontStroke': Paint()
        ..color = color.withOpacity(baseOpacity + interactionBoost)
        ..strokeWidth = 2.5 + (isInteracting ? 1.2 : 0.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      'frontFill': Paint()
        ..color =
            color.withOpacity(0.06 * avgLighting + interactionBoost * 0.04)
        ..style = PaintingStyle.fill,
      'vertices': Paint()
        ..color = color.withOpacity(0.95 + interactionBoost)
        ..style = PaintingStyle.fill,
      'highlightedVertex': Paint()
        ..color = color.withOpacity(1.0)
        ..style = PaintingStyle.fill,
      'glow': Paint()
        ..color = color.withOpacity(0.15 + interactionBoost * 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0,
    };
  }

  void _drawBackgroundEffects(Canvas canvas, Size size, Offset center) {
    if (!isInteracting) return;

    // Interaction halo with pulsing effect
    final haloRadius = 180 + math.sin(animationProgress * math.pi * 6) * 20;
    final haloPaint = Paint()
      ..color = color.withOpacity(0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60.0);

    canvas.drawCircle(center, haloRadius, haloPaint);
  }

  void _drawShape(
    Canvas canvas,
    List<Offset> frontPoints,
    List<Offset> backPoints,
    List<double> depths,
    Map<String, Paint> paints,
  ) {
    if (frontPoints.length < 2) return;

    // Draw glow effect first for interaction
    if (isInteracting) {
      _drawPath(canvas, frontPoints, paints['glow']!, useSmoothing: false);
    }

    // Draw back face
    _drawPath(canvas, backPoints, paints['backFace']!, useSmoothing: false);

    // Draw connection lines with depth-based opacity
    _drawConnections(
        canvas, frontPoints, backPoints, depths, paints['connections']!);

    // Draw front face fill
    if (frontPoints.length > 2) {
      _drawPath(canvas, frontPoints, paints['frontFill']!, useSmoothing: false);
    }

    // Draw front face stroke - this is the main shape outline
    _drawPath(canvas, frontPoints, paints['frontStroke']!, useSmoothing: false);

    // Draw vertices with enhanced styling
    _drawVertices(canvas, frontPoints, depths, paints);

    // Draw special effects
    _drawSpecialEffects(canvas, frontPoints, backPoints);
  }

  // FIXED: This method now properly handles geometric shapes without unwanted smoothing
  void _drawPath(Canvas canvas, List<Offset> points, Paint paint,
      {bool useSmoothing = false}) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    if (useSmoothing && points.length > 4) {
      // Only use smooth curves for organic shapes like waves, spirals, etc.
      for (var i = 1; i < points.length - 1; i++) {
        final cp1 = Offset(
          points[i - 1].dx + (points[i].dx - points[i - 1].dx) * 0.3,
          points[i - 1].dy + (points[i].dy - points[i - 1].dy) * 0.3,
        );
        final cp2 = Offset(
          points[i].dx + (points[i + 1].dx - points[i].dx) * 0.3,
          points[i].dy + (points[i + 1].dy - points[i].dy) * 0.3,
        );

        if (i == 1) {
          path.quadraticBezierTo(cp1.dx, cp1.dy, points[i].dx, points[i].dy);
        } else {
          path.cubicTo(
              cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
        }
      }
      path.lineTo(points.last.dx, points.last.dy);
    } else {
      // Use straight lines for geometric shapes - this preserves square corners
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    // Close the path properly for filled shapes
    if (paint.style == PaintingStyle.fill && points.length > 2) {
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  void _drawConnections(
    Canvas canvas,
    List<Offset> frontPoints,
    List<Offset> backPoints,
    List<double> depths,
    Paint basePaint,
  ) {
    for (var i = 0; i < math.min(frontPoints.length, backPoints.length); i++) {
      final depthOpacity = (1.0 - depths[i] * 0.4).clamp(0.25, 1.0);
      final connectionPaint = Paint()
        ..color =
            basePaint.color.withOpacity(basePaint.color.opacity * depthOpacity)
        ..strokeWidth = basePaint.strokeWidth * depthOpacity
        ..style = basePaint.style
        ..strokeCap = basePaint.strokeCap;

      canvas.drawLine(frontPoints[i], backPoints[i], connectionPaint);
    }
  }

  void _drawVertices(
    Canvas canvas,
    List<Offset> points,
    List<double> depths,
    Map<String, Paint> paints,
  ) {
    for (var i = 0; i < points.length; i++) {
      final baseSize = 2.0 + (isInteracting ? 1.5 : 0.0);
      final depthSize = baseSize * (1.3 - depths[i] * 0.3);

      // Highlight important vertices (corners, endpoints)
      final isImportant = i == 0 ||
          i == points.length - 1 ||
          (points.length > 4 && i % (points.length ~/ 4) == 0);

      final paint =
          isImportant ? paints['highlightedVertex']! : paints['vertices']!;

      canvas.drawCircle(points[i], depthSize, paint);

      // Enhanced vertex glow for interaction
      if (isInteracting && isImportant) {
        final glowPaint = Paint()
          ..color = color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawCircle(points[i], depthSize + 3, glowPaint);
      }
    }
  }

  void _drawSpecialEffects(
    Canvas canvas,
    List<Offset> frontPoints,
    List<Offset> backPoints,
  ) {
    if (!isInteracting || frontPoints.length < 3) return;

    // Energy lines between non-adjacent vertices
    final energyPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Draw diagonal connections for complexity
    if (frontPoints.length >= 4) {
      for (var i = 0; i < frontPoints.length - 2; i += 2) {
        if (i + 2 < frontPoints.length) {
          canvas.drawLine(frontPoints[i], frontPoints[i + 2], energyPaint);
        }
      }
    }
  }

  void _drawInteractionFeedback(Canvas canvas, Size size, Offset center) {
    if (!isInteracting) return;

    // Subtle pulsing border with rounded corners
    final borderPaint = Paint()
      ..color = color.withOpacity(0.06)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final borderRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.85,
      height: size.height * 0.85,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(borderRect, const Radius.circular(25)),
      borderPaint,
    );
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final emptyPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Draw placeholder with dashed effect
    final radius = 60.0;
    final dashLength = 8.0;
    final gapLength = 6.0;
    final circumference = 2 * math.pi * radius;
    final totalDashLength = dashLength + gapLength;
    final dashCount = (circumference / totalDashLength).floor();

    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i * totalDashLength / radius);
      final endAngle = startAngle + (dashLength / radius);

      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );

      canvas.drawPath(path, emptyPaint);
    }

    // Enhanced guide text
    final textStyle = TextStyle(
      color: color.withOpacity(0.7),
      fontSize: 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.2,
    );

    final textSpan = TextSpan(
      text: 'CREATE OR SELECT SHAPE',
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + 100,
      ),
    );
  }

  void _drawDebugInfo(
    Canvas canvas,
    Size size,
    List<Offset> frontPoints,
    List<Offset> backPoints,
    List<double> depths,
  ) {
    final debugStyle = TextStyle(
      color: Colors.white.withOpacity(0.8),
      fontSize: 11,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w500,
    );

    final debugInfo = [
      'VERTICES: ${points.length}',
      'SCALE: ${scale.toStringAsFixed(2)}x',
      'EXTRUSION: ${extrusion.toStringAsFixed(2)}',
      'TWIST: ${(twist * 180 / math.pi).toStringAsFixed(1)}°',
      'ROTATION: X${(rotationX * 180 / math.pi).toStringAsFixed(1)}° Y${(rotationY * 180 / math.pi).toStringAsFixed(1)}°',
      'INTERACTIVE: ${isInteracting ? "YES" : "NO"}',
      'ANIMATION: ${(animationProgress * 100).toStringAsFixed(0)}%',
    ];

    // Background for debug info
    final debugBg = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 5, 200, 120),
        const Radius.circular(8),
      ),
      debugBg,
    );

    for (var i = 0; i < debugInfo.length; i++) {
      final textSpan = TextSpan(text: debugInfo[i], style: debugStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(12, 12 + i * 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomShapePainter oldDelegate) {
    return points != oldDelegate.points ||
        rotationX != oldDelegate.rotationX ||
        rotationY != oldDelegate.rotationY ||
        scale != oldDelegate.scale ||
        extrusion != oldDelegate.extrusion ||
        twist != oldDelegate.twist ||
        color != oldDelegate.color ||
        isInteracting != oldDelegate.isInteracting ||
        animationProgress != oldDelegate.animationProgress ||
        showDebugInfo != oldDelegate.showDebugInfo;
  }
}
