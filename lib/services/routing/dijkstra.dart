import 'package:collection/collection.dart';

/// One step out of a node in the weighted graph.
typedef WeightedNeighbour = ({String to, double weight});

/// Lookup used by [Dijkstra] to walk a graph without owning its storage.
typedef NeighbourLookup = Iterable<WeightedNeighbour> Function(String node);

/// Plain Dijkstra shortest path over the campus road network.
abstract final class Dijkstra {
  /// Returns the node ids from [start] to [goal], or `null` when unreachable.
  ///
  /// The road network is small (a few hundred nodes), so a binary heap is more
  /// than enough and keeps this dependency-free and deterministic.
  static List<String>? shortestPath({
    required String start,
    required String goal,
    required NeighbourLookup neighbours,
  }) {
    if (start == goal) {
      return <String>[start];
    }
    final distances = <String, double>{start: 0};
    final previous = <String, String>{};
    final settled = <String>{};
    final queue = HeapPriorityQueue<({double distance, String node})>(
      (a, b) => a.distance.compareTo(b.distance),
    )..add((distance: 0, node: start));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!settled.add(current.node)) {
        continue;
      }
      if (current.node == goal) {
        break;
      }
      for (final edge in neighbours(current.node)) {
        final candidate = current.distance + edge.weight;
        final known = distances[edge.to];
        if (known == null || candidate < known - 1e-9) {
          distances[edge.to] = candidate;
          previous[edge.to] = current.node;
          queue.add((distance: candidate, node: edge.to));
        }
      }
    }

    if (!distances.containsKey(goal)) {
      return null;
    }
    final path = <String>[goal];
    var node = goal;
    while (node != start) {
      final parent = previous[node];
      if (parent == null) {
        return null;
      }
      node = parent;
      path.add(node);
    }
    return path.reversed.toList(growable: false);
  }
}
