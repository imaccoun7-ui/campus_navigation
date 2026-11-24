import 'dart:ui';

/// A campus gate, positioned in image pixels of the campus illustration.
class Gate {
  const Gate({required this.name, required this.x, required this.y});

  factory Gate.fromJson(Map<String, dynamic> json) {
    return Gate(
      name: json['name'] as String? ?? 'Gate',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  final String name;
  final double x;
  final double y;

  Offset get position => Offset(x, y);

  Map<String, dynamic> toJson() => {'name': name, 'x': x, 'y': y};
}
