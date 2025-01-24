// ignore_for_file: avoid_print

typedef MessageFunction = String Function();

abstract class Logger {
  const factory Logger.noop() = _NoOpLogger;
  const factory Logger.console() = _ConsoleLogger;
  const Logger._();

  void log(MessageFunction message);
  void warn(MessageFunction message);
}

class _NoOpLogger extends Logger {
  const _NoOpLogger() : super._();

  @override
  void log(MessageFunction message) {}
  @override
  void warn(MessageFunction message) {}
}

class _ConsoleLogger extends Logger {
  const _ConsoleLogger() : super._();

  @override
  void log(MessageFunction message) {
    print(message());
  }

  @override
  void warn(MessageFunction message) {
    final t = message();
    print('WARN: $t');
  }
}

// 扩展 Logger 类，添加 info 和 severe 方法
extension LoggerExtensions on Logger {
  void info(MessageFunction message) {
    log(message);
  }

  void severe(MessageFunction message) {
    warn(() => 'ERROR: ${message()}');
  }
}
