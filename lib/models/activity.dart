import 'package:hive/hive.dart';

part 'activity.g.dart'; // Isso será gerado automaticamente

@HiveType(typeId: 0)
class Activity extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String module;

  @HiveField(2)
  DateTime timestamp;

  @HiveField(3)
  bool isDone;

  Activity({
    required this.title,
    required this.module,
    required this.timestamp,
    this.isDone = false,
  });
}