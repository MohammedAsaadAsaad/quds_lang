/// General-purpose, capability-gated live telemetry / sensor / stream host bridge
/// (`QudsStreamBridge`).
///
/// Allows ANY host application (Flutter mobile sensors, microphone FFT buffers,
/// GPS, Bluetooth/Serial IoT devices, WebSocket market feeds, or industrial DAQ)
/// to stream real-time data channels into Quds scripts safely under
/// [QudsExecutionPolicy] without coupling `package:quds` to any platform plugin.
///
/// 100% pure Dart (zero `dart:io` or Flutter dependencies).
library;

import 'dart:collection';
import 'dart:math' as math;

import 'host_bridge.dart';

/// Timestamped reading stored inside a [QudsStreamBridge] channel ring buffer.
class QudsStreamSample {
  const QudsStreamSample({
    required this.value,
    required this.timestampMicros,
  });

  final Object? value;
  final int timestampMicros;
}

/// Host-owned ring-buffered channel hub exposing live streams to Quds scripts
/// via a capability-gated [QudsHostModule] (e.g. `use host:stream as s`).
class QudsStreamBridge {
  QudsStreamBridge({
    this.uri = 'host:stream',
    this.description =
        'Capability-gated real-time sensor, telemetry, and hardware stream bridge.',
    this.requiredCapability,
    this.maxBufferSize = 512,
  });

  final String uri;
  final String description;
  final String? requiredCapability;
  final int maxBufferSize;

  final Map<String, ListQueue<QudsStreamSample>> _channels = {};

  /// All registered channel names.
  List<String> get channelNames => List.unmodifiable(_channels.keys);

  /// Pushes a new reading [value] onto [channel], respecting [maxBufferSize].
  void push(String channel, Object? value, {int? timestampMicros}) {
    final queue = _channels.putIfAbsent(channel, () => ListQueue());
    queue.addLast(QudsStreamSample(
      value: value,
      timestampMicros: timestampMicros ?? DateTime.now().microsecondsSinceEpoch,
    ));
    while (queue.length > maxBufferSize) {
      queue.removeFirst();
    }
  }

  /// Convenience helper for pushing a 3-axis sensor reading (`x, y, z`).
  void pushVec3(String channel, double x, double y, double z) =>
      push(channel, {'x': x, 'y': y, 'z': z});

  /// Returns the latest reading on [channel], or `null` if empty.
  Object? latest(String channel) {
    final q = _channels[channel];
    return (q == null || q.isEmpty) ? null : q.last.value;
  }

  /// Returns up to [limit] most recent values on [channel] in chronological order.
  List<Object?> history(String channel, {int limit = 128}) {
    final q = _channels[channel];
    if (q == null || q.isEmpty) return const [];
    final list = [for (final s in q) s.value];
    if (list.length <= limit) return list;
    return list.sublist(list.length - limit);
  }

  /// Clears buffered samples on [channel], or all channels when omitted.
  void clear([String? channel]) {
    if (channel == null) {
      _channels.clear();
    } else {
      _channels.remove(channel);
    }
  }

  /// Builds the capability-gated [QudsHostModule] to attach to a [QudsSession].
  QudsHostModule toHostModule() {
    final builder = QudsHostModule.builder(uri, description: description);

    builder.function(
      'channels',
      (pos, named, ctx) => List<String>.from(_channels.keys),
      capability: requiredCapability,
      signature: 'channels() -> List<String>',
      documentation:
          'Returns all available live telemetry/sensor channel names.',
    );

    builder.function(
      'latest',
      (pos, named, ctx) => latest('${pos[0]}'),
      capability: requiredCapability,
      signature: 'latest(channel: String) -> Object?',
      documentation: 'Returns the most recent sample pushed to `channel`.',
    );

    builder.function(
      'history',
      (pos, named, ctx) {
        final channel = '${pos[0]}';
        final limit =
            ((named['limit'] ?? (pos.length > 1 ? pos[1] : 128)) as num)
                .toInt()
                .clamp(1, maxBufferSize);
        return history(channel, limit: limit);
      },
      capability: requiredCapability,
      signature: 'history(channel: String, limit: int = 128) -> List<Object?>',
      documentation:
          'Returns up to `limit` chronological readings from `channel`.',
    );

    builder.function(
      'stats',
      (pos, named, ctx) {
        final vals = [
          for (final v in history('${pos[0]}', limit: maxBufferSize))
            if (v is num) v.toDouble(),
        ];
        if (vals.isEmpty) {
          return <String, Object?>{
            'count': 0,
            'min': 0.0,
            'max': 0.0,
            'mean': 0.0,
            'std': 0.0,
          };
        }
        var minV = vals.first, maxV = vals.first, sum = 0.0;
        for (final v in vals) {
          if (v < minV) minV = v;
          if (v > maxV) maxV = v;
          sum += v;
        }
        final mean = sum / vals.length;
        var vAcc = 0.0;
        for (final v in vals) {
          final d = v - mean;
          vAcc += d * d;
        }
        return <String, Object?>{
          'count': vals.length,
          'min': minV,
          'max': maxV,
          'mean': mean,
          'std': math.sqrt(vAcc / vals.length),
        };
      },
      capability: requiredCapability,
      signature: 'stats(channel: String) -> Map<String, Object?>',
      documentation:
          'Computes {count, min, max, mean, std} over buffered numeric samples in `channel`.',
    );

    return builder.build();
  }
}
