import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RetryQueueManager {
  static const String _queueKey = 'notification_retry_queue';
  final Duration retryInterval;
  final int maxRetries;
  Timer? _retryTimer;
  List<RetryItem> _queue = [];
  bool _isProcessing = false;
  bool _isInitialized = false;

  final Future<bool> Function(Map<String, dynamic>) onRetry;

  static Future<RetryQueueManager> initialize({
    required Future<bool> Function(Map<String, dynamic>) onRetry,
    Duration retryInterval = const Duration(minutes: 1),
    int maxRetries = 5,
  }) async {
    final manager = RetryQueueManager._internal(
      onRetry: onRetry,
      retryInterval: retryInterval,
      maxRetries: maxRetries,
    );
    await manager._initializeQueue();
    return manager;
  }

  RetryQueueManager._internal({
    required this.onRetry,
    required this.retryInterval,
    required this.maxRetries,
  });

  Future<void> _initializeQueue() async {
    if (!_isInitialized) {
      await _loadQueue();
      _startRetryTimer();
      _isInitialized = true;
    }
  }

  Future<void> _loadQueue() async {
    try {
      print('Verificando cola');
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson != null) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _queue = queueList.map((item) => RetryItem.fromJson(item as Map<String, dynamic>)).toList();
        print('Cola cargada: ${_queue.length} items');
      }
    } catch (e) {
      print('Error cargando cola de reintentos: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((item) => item.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
      print('Cola guardada: ${_queue.length} items');
    } catch (e) {
      print('Error guardando cola de reintentos: $e');
    }
  }

  Future<void> addToQueue(Map<String, dynamic> data) async {
    if (!_isInitialized) {
      await _initializeQueue();
    }
    
    final retryItem = RetryItem(
      data: data,
      timestamp: DateTime.now(),
      retryCount: 0,
    );
    _queue.add(retryItem);
    await _saveQueue();
    print('Item agregado a la cola de reintentos. Total items: ${_queue.length}');
  }

  Future<void> processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    print('Procesando cola de reintentos... Items: ${_queue.length}');

    try {
      final itemsToRemove = <RetryItem>[];

      for (var item in _queue) {
        if (item.retryCount >= maxRetries) {
          print('Item excedió máximo de reintentos: ${item.data}');
          itemsToRemove.add(item);
          continue;
        }

        try {
          final success = await onRetry(item.data);
          if (success) {
            print('Reintento exitoso para item: ${item.data}');
            itemsToRemove.add(item);
          } else {
            item.retryCount++;
            print('Reintento fallido #${item.retryCount} para item: ${item.data}');
          }
        } catch (e) {
          print('Error en reintento: $e');
          item.retryCount++;
        }
      }

      _queue.removeWhere((item) => itemsToRemove.contains(item));
      await _saveQueue();
    } finally {
      _isProcessing = false;
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(retryInterval, (timer) async {
      await processQueue();
    });
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    if (_queue.isNotEmpty) {
      await _saveQueue();
    }
  }
}

class RetryItem {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retryCount;

  RetryItem({
    required this.data,
    required this.timestamp,
    required this.retryCount,
  });

  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };

  factory RetryItem.fromJson(Map<String, dynamic> json) => RetryItem(
    data: Map<String, dynamic>.from(json['data']),
    timestamp: DateTime.parse(json['timestamp']),
    retryCount: json['retryCount'],
  );
}