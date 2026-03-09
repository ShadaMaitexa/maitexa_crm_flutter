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
    await FirebaseService.addActivity(
      leadId,
      'Status Update',
      'Status changed to $status',
    );
  }

  Future<void> updateLeadDetails(
    String leadId,
    Map<String, dynamic> data,
  ) async {
    await FirebaseService.updateLead(leadId, data);
    await FirebaseService.addActivity(
      leadId,
      'Profile Updated',
      'Lead details was updated',
    );
  }

  Future<void> addNote(String leadId, String note) async {
    await FirebaseService.addNote(leadId, note);
  }

  Future<void> recordWhatsAppActivity(String leadId) async {
    await FirebaseService.addActivity(
      leadId,
      'WhatsApp Sent',
      'Sent course inquiry message via WhatsApp',
    );
  }

  Future<void> launchWhatsApp(String rawPhone, {String? customMessage}) async {
    // Sanitize phone number: remove non-digits
    String phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    // Add default country code +91 if only 10 digits provided
    if (phone.length == 10 && !phone.startsWith('91')) {
      phone = '91$phone';
    }

    final message =
        customMessage ??
        "Hello,\n\nThank you for contacting our training institute.\n\nWhich course are you interested in?\n\n1. Python\n2. Data Analytics\n3. Flutter\n4. AI";
    final encodedMessage = Uri.encodeComponent(message);

    // ---------------------------------------------------------------
    // Priority order:
    //  1. WhatsApp Business deep link (whatsapp.biz:// scheme)
    //     → Opens ONLY WhatsApp Business (com.whatsapp.w4b)
    //  2. Regular WhatsApp deep link (whatsapp:// scheme)
    //     → Opens regular WhatsApp (com.whatsapp)
    //  3. Official wa.me short link  → system picks installed WA app
    //  4. api.whatsapp.com web link  → browser fallback
    // ---------------------------------------------------------------
    final List<Uri> uris = [
      // 1️⃣  WhatsApp Business — uses the distinct `whatsapp.biz` URI scheme
      Uri.parse("whatsapp.biz://send?phone=$phone&text=$encodedMessage"),

      // 2️⃣  Regular WhatsApp deep link
      Uri.parse("whatsapp://send?phone=$phone&text=$encodedMessage"),

      // 3️⃣  Official short-link (opens whichever WA is set as default)
      Uri.parse("https://wa.me/$phone?text=$encodedMessage"),

      // 4️⃣  Web API fallback (opens in browser)
      Uri.parse(
        "https://api.whatsapp.com/send?phone=$phone&text=$encodedMessage",
      ),
    ];

    for (final uri in uris) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return; // success — exit early
        }
      } catch (_) {
        // try next URI
      }
    }

    // Last resort: force open in external browser
    await launchUrl(
      Uri.parse("https://wa.me/$phone?text=$encodedMessage"),
      mode: LaunchMode.externalApplication,
    );
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
