import 'package:event_bus/event_bus.dart';

final eventBus = EventBus();

class DemoMode{
  final bool isActive;
  DemoMode({required this.isActive});
}