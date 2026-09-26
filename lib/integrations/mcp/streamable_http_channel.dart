import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:stream_channel/stream_channel.dart';
import '../../core/logging/logger.dart';

/// Implements MCP Streamable HTTP transport over `StreamChannel<String>`.
class StreamableHttpChannel extends StreamChannelMixin<String> {
  StreamableHttpChannel({
    required this.endpointUrl,
    this.bearerToken,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 120),
              ),
            ) {
    _initChannels();
  }

  final String endpointUrl;
  final String? bearerToken;
  final Dio _dio;

  String? _sessionId;
  String? _lastEventId;

  late final StreamController<String> _incomingController;
  late final StreamController<String> _outgoingController;

  StreamSubscription<void>? _sseSubscription;
  bool _isClosed = false;

  void _initChannels() {
    _incomingController = StreamController<String>.broadcast();
    _outgoingController = StreamController<String>();

    _outgoingController.stream.listen(
      _handleOutgoingMessage,
      onError: (Object e) => AppLogger.error('MCP outgoing error', e),
      onDone: close,
    );
  }

  Map<String, String> _buildHeaders({bool isSse = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': isSse
          ? 'text/event-stream'
          : 'application/json, text/event-stream',
    };
    if (bearerToken != null && bearerToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    if (_sessionId != null) {
      headers['Mcp-Session-Id'] = _sessionId!;
    }
    if (_lastEventId != null) {
      headers['Last-Event-ID'] = _lastEventId!;
    }
    return headers;
  }

  Future<void> _handleOutgoingMessage(String message) async {
    if (_isClosed) return;

    try {
      final headers = _buildHeaders();
      final response = await _dio.post<dynamic>(
        endpointUrl,
        data: message,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );

      // Check for Mcp-Session-Id header from server
      final respSessionId = response.headers.value('mcp-session-id');
      if (respSessionId != null && respSessionId.isNotEmpty) {
        _sessionId = respSessionId;
      }

      final contentType = response.headers.value('content-type') ?? '';
      if (contentType.contains('text/event-stream')) {
        _parseSseChunk(response.data.toString());
      } else if (response.data != null) {
        final body = response.data.toString().trim();
        if (body.isNotEmpty) {
          _incomingController.add(body);
        }
      }
    } catch (e) {
      AppLogger.warning('MCP message failed ($endpointUrl): $e');
      if (!_isClosed) {
        _incomingController.addError(e);
      }
    }
  }

  Future<void> startSseStream() async {
    if (_isClosed || _sseSubscription != null) return;

    try {
      final headers = _buildHeaders(isSse: true);
      final response = await _dio.get<ResponseBody>(
        endpointUrl,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      final respSessionId = response.headers.value('mcp-session-id');
      if (respSessionId != null) {
        _sessionId = respSessionId;
      }

      final stream = response.data?.stream;
      if (stream != null) {
        var buffer = '';
        _sseSubscription = stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .listen(
          (chunk) {
            buffer += chunk;
            final lines = buffer.split('\n');
            buffer = lines.removeLast();
            for (final line in lines) {
              _parseSseLine(line);
            }
          },
          onError: (Object e) {
            AppLogger.warning('MCP SSE stream error, will reconnect', e);
            _reconnectSse();
          },
          onDone: () {
            if (!_isClosed) {
              _reconnectSse();
            }
          },
        );
      }
    } catch (e) {
      AppLogger.warning('MCP SSE stream could not be opened: $e');
    }
  }

  void _parseSseChunk(String chunk) {
    final lines = chunk.split('\n');
    for (final line in lines) {
      _parseSseLine(line);
    }
  }

  void _parseSseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.startsWith('id:')) {
      _lastEventId = trimmed.substring(3).trim();
    } else if (trimmed.startsWith('data:')) {
      final dataContent = trimmed.substring(5).trim();
      if (dataContent.isNotEmpty && dataContent != '[DONE]') {
        _incomingController.add(dataContent);
      }
    }
  }

  void _reconnectSse() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    if (!_isClosed) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!_isClosed) {
          startSseStream();
        }
      });
    }
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _sseSubscription?.cancel();
    _sseSubscription = null;

    if (_sessionId != null) {
      try {
        await _dio.delete<void>(
          endpointUrl,
          options: Options(headers: _buildHeaders()),
        );
      } catch (_) {}
    }

    await _incomingController.close();
    await _outgoingController.close();
  }

  @override
  Stream<String> get stream => _incomingController.stream;

  @override
  StreamSink<String> get sink => _outgoingController.sink;
}
