import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../services/scoring_service.dart';
import '../models/task_model.dart';
import '../models/day_record_model.dart';

class DemoSeeder {
  static Future<void> seed() async {
    try {
      debugPrint('DemoSeeder: starting seed...');
      await wipe();

      final rng = Random(42);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = today.subtract(const Duration(days: 183));
      const totalDays = 184; // 183 days ago + today

      final List<String> taskSids = [];
      final List<Task> allCreatedTasks = [];

      // 1. Create Tasks
      final taskConfigs = [
        {'name': '[demo] Meditate', 'type': TaskType.daily, 'freq': FrequencyType.daily, 'perpetual': true, 'created': startDate},
        {'name': '[demo] Read 30 min', 'type': TaskType.daily, 'freq': FrequencyType.daily, 'perpetual': true, 'created': startDate},
        {'name': '[demo] Workout', 'type': TaskType.daily, 'freq': FrequencyType.weekly, 'target': 4, 'perpetual': true, 'created': startDate},
        {'name': '[demo] Learn Spanish', 'type': TaskType.daily, 'freq': FrequencyType.daily, 'perpetual': true, 'created': startDate},
        {'name': '[demo] Write journal', 'type': TaskType.daily, 'freq': FrequencyType.weekly, 'target': 3, 'perpetual': true, 'created': startDate},
        {'name': '[demo] Cold shower', 'type': TaskType.temporary, 'freq': FrequencyType.daily, 'duration': 60, 'perpetual': false, 'created': today.subtract(const Duration(days: 10))},
      ];

      for (var config in taskConfigs) {
        final sid = const Uuid().v4();
        final task = Task(
          sid: sid,
          name: config['name'] as String,
          type: config['type'] as TaskType,
          frequencyType: config['freq'] as FrequencyType,
          isPerpetual: config['perpetual'] as bool,
          weeklyTarget: (config['target'] as int?) ?? 1,
          durationDays: (config['duration'] as int?) ?? 0,
          createdAt: config['created'] as DateTime,
        );
        await DatabaseService.instance.addTask(task);
        taskSids.add(sid);
        allCreatedTasks.add(task);
      }

      // 2. Patterns
      bool didOnDay(int taskIndex, int dayIndex) {
        // dayIndex 0 is startDate, dayIndex 183 is today.
        
        switch (taskIndex) {
          case 0: // Meditate
            return rng.nextDouble() < 0.95;
          case 1: // Read
            final breakStart = totalDays - 66; // approx 2 months ago
            if (dayIndex >= breakStart && dayIndex < breakStart + 12) return false;
            return rng.nextDouble() < 0.75;
          case 2: // Workout
            return rng.nextDouble() < 0.50;
          case 3: // Learn Spanish
            if (dayIndex < 30) return false;
            // Linear ramp from 30% at day 30 to 85% at day 183
            final progress = (dayIndex - 30) / (totalDays - 1 - 30);
            final prob = 0.30 + (progress * (0.85 - 0.30));
            return rng.nextDouble() < prob;
          case 4: // Write journal
            return rng.nextDouble() < 0.80;
          case 5: // Cold shower
            if (dayIndex < totalDays - 11) return false;
            return rng.nextDouble() < 0.80;
          default:
            return false;
        }
      }

      // 3. Cheat Days
      final cheatDays = <int>{};
      while (cheatDays.length < 4) {
        cheatDays.add(rng.nextInt(totalDays - 30));
      }

      // 4. Generate Records
      final List<DayRecord> history = [];
      for (int i = 0; i < totalDays; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        
        List<String> completedSids = [];
        if (i == totalDays - 1) {
          // Today: force exactly first 3
          completedSids = taskSids.sublist(0, 3);
        } else {
          for (int t = 0; t < taskSids.length; t++) {
            if (didOnDay(t, i)) {
              completedSids.add(taskSids[t]);
            }
          }
        }

        final cheatUsed = cheatDays.contains(i);
        final isRecent = i >= totalDays - 14;
        final pomos = isRecent ? (2 + rng.nextInt(5)) : 0;

        final tempRecord = DayRecord(
          date: dateStr,
          completedTaskIds: completedSids,
          cheatUsed: cheatUsed,
          pomodoroSessionsCompleted: pomos,
          pomodoroGoal: 4,
        );

        // Filter tasks active on this date for scoring
        final activeTasks = allCreatedTasks.where((task) {
          final taskCreated = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
          final d = DateTime(date.year, date.month, date.day);
          if (d.isBefore(taskCreated)) return false;
          if (task.type == TaskType.temporary) {
            return !d.isBefore(taskCreated) && d.isBefore(taskCreated.add(Duration(days: task.durationDays)));
          }
          if (task.isPerpetual) return true;
          return d.isBefore(taskCreated.add(Duration(days: task.durationDays)));
        }).toList();

        final score = ScoringService.calculateDayScore(
          allTasks: activeTasks,
          dayRecord: tempRecord,
          history: history,
        );

        final finalRecord = tempRecord.copyWith(
          visualState: score.visualState,
          completionScore: score.completionScore,
        );

        await DatabaseService.instance.createOrUpdateDayRecord(finalRecord);
        history.add(finalRecord);
      }

      debugPrint('DemoSeeder: seeded $totalDays days and ${allCreatedTasks.length} tasks');
    } catch (e) {
      debugPrint('DemoSeeder seed failed: $e');
      rethrow;
    }
  }

  static Future<void> wipe() async {
    try {
      final tasks = await DatabaseService.instance.getAllTasks(includeArchived: true);
      final demoTasks = tasks.where((t) => t.name.startsWith('[demo] ')).toList();
      
      int count = 0;
      for (var task in demoTasks) {
        await DatabaseService.instance.deleteTaskPermanently(task.sid);
        count++;
      }
      debugPrint('DemoSeeder: wiped $count demo tasks');
    } catch (e) {
      debugPrint('DemoSeeder wipe failed: $e');
      rethrow;
    }
  }
}
