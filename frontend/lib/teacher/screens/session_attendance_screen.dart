import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/models/session_model.dart';
import '../../shared/models/attendance_model.dart';
import '../../shared/services/attendance_service.dart';
import '../../core/config/app_config.dart';

class SessionAttendanceScreen extends StatelessWidget {
  final SessionModel session;

  const SessionAttendanceScreen({Key? key, required this.session}) : super(key: key);

  // --- NEW: Download Logic ---
  Future<void> _downloadReport(BuildContext context) async {
    final String url = '${AppConfig.baseUrl}/export/session/${session.id}';
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch download link")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceService attendanceService = AttendanceService();

    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        backgroundColor: Colors.blue,
        actions: [
          // --- NEW: Download Button ---
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export to Excel",
            onPressed: () => _downloadReport(context),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Date: ${DateFormat('yyyy-MM-dd').format(session.startTime)}"),
                Text("Time: ${DateFormat('hh:mm a').format(session.startTime)} - ${DateFormat('hh:mm a').format(session.endTime)}"),
                Text("Class: ${session.course ?? ''} ${session.branch ?? ''} ${session.year ?? ''}"),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<AttendanceModel>>(
              future: attendanceService.getSessionAttendance(session.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No students marked present yet."));
                }
                final attendees = snapshot.data!;
                return ListView.builder(
                  itemCount: attendees.length,
                  itemBuilder: (context, index) {
                    final student = attendees[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        foregroundColor: Colors.green[800],
                        child: Text(student.studentName[0].toUpperCase()),
                      ),
                      title: Text(student.studentName),
                      subtitle: Text("Checked in: ${DateFormat('hh:mm a').format(student.checkInTime)}"),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}