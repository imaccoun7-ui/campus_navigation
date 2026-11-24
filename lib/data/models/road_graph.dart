import 'dart:ui';

/// One centerline segment between two nodes of the campus road network.
class RoadEdge {
  const RoadEdge(this.a, this.b);

  factory RoadEdge.fromJson(List<dynamic> json) =>
      RoadEdge(json[0] as String, json[1] as String);

  final String a;
  final String b;
}

/// The road centerlines derived from the dark paved paths in `buildings.json`'s
/// campus illustration.
///
/// All coordinates are image pixels. Routes densify these edges at runtime, so
/// improving the network only means editing the JSON.
class RoadGraph {
  const RoadGraph({required this.nodes, required this.edges});

  factory RoadGraph.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as Map<String, dynamic>? ?? const {};
    final nodes = <String, Offset>{};
    rawNodes.forEach((id, value) {
      final pair = value as List<dynamic>;
      nodes[id] = Offset(
        (pair[0] as num).toDouble(),
        (pair[1] as num).toDouble(),
      );
    });
    final rawEdges = json['edges'] as List<dynamic>? ?? const <dynamic>[];
    final edges = rawEdges
        .map((edge) => RoadEdge.fromJson(edge as List<dynamic>))
        .toList(growable: false);
    return RoadGraph(nodes: nodes, edges: edges);
  }

  final Map<String, Offset> nodes;
  final List<RoadEdge> edges;

  bool get isEmpty => nodes.isEmpty || edges.isEmpty;
}
