import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Encodes a JSON message with a 4-byte big-endian length prefix.
///
/// Wire format: [4-byte big-endian length][UTF-8 JSON bytes]
///
/// This ensures the receiver can always determine message boundaries
/// regardless of how TCP segments are delivered (partial reads,
/// multiple messages per segment, etc.).
List<int> encodeFrame(Map<String, dynamic> message) {
  final jsonBytes = utf8.encode(jsonEncode(message));
  final length = jsonBytes.length;
  final header = ByteData(4)..setUint32(0, length, Endian.big);
  return [...header.buffer.asUint8List(), ...jsonBytes];
}

/// A [StreamTransformer] that reassembles length-prefixed frames from a
/// raw TCP byte stream.
///
/// Each frame on the wire is:
///   [4-byte big-endian length header][UTF-8 JSON payload of that length]
///
/// Because TCP is a stream protocol, a single `recv()` may contain a
/// partial frame, exactly one frame, or multiple concatenated frames.
/// This transformer buffers incoming bytes and only emits complete
/// JSON strings once the full payload has been received.
class LengthPrefixedFrameDecoder
    extends StreamTransformerBase<List<int>, String> {
  const LengthPrefixedFrameDecoder();

  @override
  Stream<String> bind(Stream<List<int>> stream) {
    return Stream<String>.eventTransformed(
      stream,
      (EventSink<String> sink) => _FrameSink(sink),
    );
  }
}

class _FrameSink implements EventSink<List<int>> {
  final EventSink<String> _outputSink;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// Length of the current frame being assembled, or null if we haven't
  /// read the 4-byte header yet.
  int? _expectedLength;

  _FrameSink(this._outputSink);

  @override
  void add(List<int> data) {
    _buffer.add(data);
    _drain();
  }

  /// Repeatedly extracts complete frames from the buffer.
  void _drain() {
    while (true) {
      final bytes = _buffer.toBytes();

      // Need at least 4 bytes for the length header.
      if (_expectedLength == null) {
        if (bytes.length < 4) return;
        final header = ByteData.sublistView(Uint8List.fromList(bytes.take(4).toList()));
        _expectedLength = header.getUint32(0, Endian.big);
      }

      final totalNeeded = 4 + _expectedLength!;
      if (bytes.length < totalNeeded) return;

      // We have a complete frame — extract the JSON payload.
      final payload = bytes.sublist(4, totalNeeded);
      final jsonString = utf8.decode(payload);
      _outputSink.add(jsonString);

      // Keep any remaining bytes for the next frame.
      final remaining = bytes.sublist(totalNeeded);
      _buffer.clear();
      if (remaining.isNotEmpty) {
        _buffer.add(remaining);
      }
      _expectedLength = null;
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _outputSink.addError(error, stackTrace);
  }

  @override
  void close() {
    _outputSink.close();
  }
}
