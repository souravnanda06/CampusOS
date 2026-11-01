import 'dart:convert';
import 'physical_validation_harness.dart';
import 'stage_simulation_controller.dart';

/// Exporter formatting physical validation runs and simulator records into CSV and JSON.
class MeshValidationExporter {
  /// Exports physical validation telemetry records to structured JSON string.
  static String exportPhysicalTelemetryToJson(List<PhysicalTestTelemetry> records) {
    final list = records.map((r) => r.toJson()).toList();
    final wrapper = {
      'exported_at': DateTime.now().toIso8601String(),
      'system': 'CampusOS Mesh M7 Validation Harness',
      'validation_type': 'PHYSICAL_HARDWARE',
      'record_count': records.length,
      'records': list,
    };
    return const JsonEncoder.withIndent('  ').convert(wrapper);
  }

  /// Exports physical validation telemetry records to RFC 4180 compliant CSV string.
  static String exportPhysicalTelemetryToCsv(List<PhysicalTestTelemetry> records) {
    final buffer = StringBuffer();
    buffer.writeln(PhysicalTestTelemetry.csvHeader());
    for (final record in records) {
      buffer.writeln(record.toCsvRow());
    }
    return buffer.toString();
  }

  /// Exports simulated stage events to structured JSON string.
  static String exportSimulationEventsToJson(List<SimulationEvent> events) {
    final list = events.map((e) {
      return {
        'event_id': e.eventId,
        'timestamp': e.timestamp.toIso8601String(),
        'scenario': e.scenario,
        'source_node': e.sourceNodeId,
        'target_node': e.targetNodeId ?? 'N/A',
        'event_type': e.eventType.name,
        'summary': e.summary,
        'details': e.details,
        'hop_count': e.hopCount,
        'success': e.isSuccess,
      };
    }).toList();

    final wrapper = {
      'exported_at': DateTime.now().toIso8601String(),
      'system': 'CampusOS Mesh M7 Stage Simulator',
      'validation_type': 'SOFTWARE_SIMULATION',
      'notice': 'SIMULATED DATA · NOT PHYSICAL RADIO MEASUREMENT',
      'event_count': events.length,
      'events': list,
    };
    return const JsonEncoder.withIndent('  ').convert(wrapper);
  }

  /// Exports simulated stage events to CSV string.
  static String exportSimulationEventsToCsv(List<SimulationEvent> events) {
    final buffer = StringBuffer();
    buffer.writeln('event_id,timestamp,scenario,source_node,target_node,event_type,summary,details,hop_count,success');
    for (final e in events) {
      buffer.writeln([
        e.eventId,
        e.timestamp.toIso8601String(),
        '"${e.scenario}"',
        e.sourceNodeId,
        e.targetNodeId ?? '',
        e.eventType.name,
        '"${e.summary}"',
        '"${e.details}"',
        e.hopCount,
        e.isSuccess ? 'TRUE' : 'FALSE',
      ].join(','));
    }
    return buffer.toString();
  }
}
