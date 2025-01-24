library line_animator;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class InterpolatedResult {
  final LatLng point;
  final double angle;
  final List<LatLng> builtPoints;
  final double animValue;
  final double controllerValue;

  InterpolatedResult({
    required this.point,
    required this.angle,
    required this.builtPoints,
    required this.animValue,
    required this.controllerValue,
  });
}

class PercentageStep {
  double percent;
  final double distance;
  final double time;

  PercentageStep({
    this.percent = 0.0,
    required this.distance,
    this.time = 10.0,
  });
}

class PointInterpolator {
  List<LatLng> builtPoints = [];
  List<LatLng> points = [];
  final List<LatLng> originalPoints;
  final double Function(LatLng, LatLng)? distanceFunc;
  late List<PercentageStep> pointDistanceSteps;
  int lastPointIndex = 1;
  double totalDistance = 0.0;
  LatLng? _previousPoint;
  late double _lastAngle = 0.0;
  LatLng? interpolatedPoint;
  final bool isReversed;

  PointInterpolator({
    required this.originalPoints,
    this.distanceFunc,
    required this.isReversed,
  }) {
    reload();
  }

  void reload() {
    lastPointIndex = 1;
    builtPoints = [];
    points = [];
    buildPointsMap();
  }

  void buildPointsMap() {
    var myDistanceFunc = distanceFunc ?? haversine;

    points = isReversed ? originalPoints.reversed.toList() : originalPoints.toList();

    builtPoints.add(points.first);
    builtPoints.add(points.first);

    pointDistanceSteps = [PercentageStep(distance: 0.0, percent: 0.0)];
    totalDistance = 0.0;

    for (var c = 0; c < points.length - 1; c++) {
      totalDistance += myDistanceFunc(points[c], points[c + 1]);
      pointDistanceSteps.add(PercentageStep(distance: totalDistance));
    }

    for (var step in pointDistanceSteps) {
      step.percent = step.distance / totalDistance;
    }
  }

  InterpolatedResult interpolate(double controllerValue, double animValue, bool interpolateBetweenPoints) {
    LatLng? thisPoint;

    for (var c = lastPointIndex; c < points.length; c++) {
      if (animValue >= pointDistanceSteps[c].distance || (c == points.length - 1)) {
        interpolatedPoint = null;
        thisPoint = points[c];
        builtPoints.add(thisPoint);
        lastPointIndex = c + 1;
      } else {
        if (interpolateBetweenPoints) {
          var lastPerc = pointDistanceSteps[c - 1].percent;
          var nextPerc = pointDistanceSteps[c].percent;

          // 防止除以0的情况
          if ((nextPerc - lastPerc).abs() > 1e-6) {
            var perc = (controllerValue - lastPerc) / (nextPerc - lastPerc);
            var intermediateLat = (points[c].latitude - points[c - 1].latitude) * perc + points[c - 1].latitude;
            var intermediateLon = (points[c].longitude - points[c - 1].longitude) * perc + points[c - 1].longitude;

            interpolatedPoint = LatLng(intermediateLat, intermediateLon);

            if (builtPoints.length > c) {
              builtPoints[c] = interpolatedPoint!;
            } else {
              builtPoints.add(interpolatedPoint!);
            }
          }
        }

        thisPoint = interpolatedPoint;
        break;
      }
    }

    thisPoint ??= points[lastPointIndex - 1];

    double angle = 0.0;
    if (_previousPoint != null) {
      angle = -atan2(thisPoint.latitude - _previousPoint!.latitude,
              thisPoint.longitude - _previousPoint!.longitude) -
          4.7128;
    }

    _lastAngle = thisPoint != _previousPoint ? angle : _lastAngle;
    _previousPoint = thisPoint;

    return InterpolatedResult(
      point: thisPoint,
      angle: _lastAngle,
      animValue: animValue,
      controllerValue: controllerValue,
      builtPoints: builtPoints,
    );
  }

  double haversine(LatLng p1, LatLng p2) {
    var lat1 = p1.latitudeInRad, lat2 = p2.latitudeInRad;
    var lon1 = p1.longitudeInRad, lon2 = p2.longitudeInRad;

    var earthRadius = 6378137.0; // 地球半径，单位：米
    return 2 * earthRadius * asin(sqrt(pow(sin((lat2 - lat1) / 2), 2) +
        cos(lat1) * cos(lat2) * pow(sin((lon2 - lon1) / 2), 2)));
  }
}

class LineAnimator extends StatefulWidget {
  final Widget child;
  final List<LatLng> originalPoints;
  final List<LatLng> builtPoints;
  final double Function(LatLng, LatLng)? distanceFunc;
  final Function? stateChangeCallback;
  final Function? duringCallback;
  final Duration duration;
  final double? begin;
  final double? end;
  final bool isReversed;
  final AnimationController? controller;
  final bool interpolateBetweenPoints;

  const LineAnimator({
    Key? key,
    required this.duration,
    required this.child,
    required this.originalPoints,
    required this.builtPoints,
    this.distanceFunc,
    this.duringCallback,
    this.stateChangeCallback,
    this.begin = 0.0,
    this.end = 1.0,
    this.controller,
    this.isReversed = false,
    this.interpolateBetweenPoints = true,
  }) : super(key: key);

  @override
  LineAnimatorState createState() => LineAnimatorState();
}

class LineAnimatorState extends State<LineAnimator> with TickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;
  late PointInterpolator interpolator;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? AnimationController(duration: widget.duration, vsync: this);
    startAnimation();
  }

  void startAnimation() {
    interpolator = PointInterpolator(
      originalPoints: widget.originalPoints,
      distanceFunc: widget.distanceFunc,
      isReversed: widget.isReversed,
    );

    animation = Tween<double>(begin: widget.begin, end: interpolator.totalDistance).animate(controller)
      ..addListener(() {
        var interpolatedResult = interpolator.interpolate(controller.value, animation.value, widget.interpolateBetweenPoints);
        widget.duringCallback?.call(interpolatedResult.builtPoints, interpolatedResult.point, interpolatedResult.angle, animation.value);
      })
      ..addStatusListener((status) {
        widget.stateChangeCallback?.call(status, interpolator.builtPoints);
      });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void didUpdateWidget(LineAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.begin != widget.begin ||
        oldWidget.originalPoints != widget.originalPoints ||
        oldWidget.isReversed != widget.isReversed) {
      interpolator = PointInterpolator(
        originalPoints: widget.originalPoints,
        distanceFunc: widget.distanceFunc,
        isReversed: widget.isReversed,
      );
      controller.reset();
      controller.forward(from: widget.begin);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
