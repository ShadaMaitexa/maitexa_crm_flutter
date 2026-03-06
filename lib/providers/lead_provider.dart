import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadProvider with ChangeNotifier {
  String _selectedFilter = 'All Calls';
  
  String get selectedFilter => _selectedFilter;

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    await FirebaseService.updateLead(leadId, {'status': status});
    await FirebaseService.addActivity(leadId, 'Status Update', 'Status changed to $status');
  }

  Future<void> updateLeadDetails(String leadId, Map<String, dynamic> data) async {
    await FirebaseService.updateLead(leadId, data);
    await FirebaseService.addActivity(leadId, 'Profile Updated', 'Lead details was updated');
  }

  Future<void> addNote(String leadId, String note) async {
    await FirebaseService.addNote(leadId, note);
  }

  Future<void> recordWhatsAppActivity(String leadId) async {
    await FirebaseService.addActivity(leadId, 'WhatsApp Sent', 'Sent course inquiry message via WhatsApp');
  }

  Future<void> launchWhatsApp(String phone) async {
    final message = "Hello,\n\nThank you for contacting our training institute.\n\nWhich course are you interested in?\n\n1. Python\n2. Data Analytics\n3. Flutter\n4. AI";
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> launchCall(String phone) async {
    final url = "tel:$phone";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> addLabel(String label) async {
    await FirebaseService.addLabel(label);
    notifyListeners();
  }
}
