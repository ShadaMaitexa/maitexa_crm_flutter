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

    final message = customMessage ?? "";
    final encodedMessage = message.isNotEmpty
        ? "&text=${Uri.encodeComponent(message)}"
        : "";

    // ---------------------------------------------------------------
    // Priority order:
    //  1. WhatsApp Business deep link (whatsapp.biz:// scheme)
    //     → Opens ONLY WhatsApp Business (com.whatsapp.w4b)
    //  2. Regular WhatsApp deep link (whatsapp:// scheme)
    //     → Opens regular WhatsApp (com.whatsapp)
    //  3. Official wa.me short link  → system picks installed WA app
    //  4. api.whatsapp.com web link  → browser fallback
    // ---------------------------------------------------------------
    final List<Map<String, dynamic>> platforms = [
      {
        'uri': Uri.parse("whatsapp.biz://send?phone=$phone$encodedMessage"),
        'desc': 'WhatsApp Business Direct',
      },
      {
        'uri': Uri.parse("https://wa.me/$phone?$encodedMessage"),
        'desc': 'Universal Link',
      },
      {
        'uri': Uri.parse("whatsapp://send?phone=$phone$encodedMessage"),
        'desc': 'WhatsApp Personal',
      },
    ];

    for (var platform in platforms) {
      final uri = platform['uri'] as Uri;
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        debugPrint("Failed to launch ${platform['desc']}: $e");
      }
    }

    // Last resort fallback
    final fallbackUri = Uri.parse(
      "https://api.whatsapp.com/send?phone=$phone$encodedMessage",
    );
    if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Launch WhatsApp with specific type (Business or Personal)
  Future<void> launchWhatsAppByType(
    String rawPhone,
    String type, {
    String? customMessage,
  }) async {
    // Sanitize phone number: remove non-digits
    String phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    // Add default country code +91 if only 10 digits provided
    if (phone.length == 10 && !phone.startsWith('91')) {
      phone = '91$phone';
    }

    final message = customMessage ?? "";
    final encodedMessage = message.isNotEmpty
        ? "&text=${Uri.encodeComponent(message)}"
        : "";

    Uri uri;
    if (type == 'business') {
      uri = Uri.parse("whatsapp.biz://send?phone=$phone$encodedMessage");
    } else {
      uri = Uri.parse("whatsapp://send?phone=$phone$encodedMessage");
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint("Failed to launch $type: $e");
    }

    // Fallback to universal link
    final fallbackUri = Uri.parse("https://wa.me/$phone$encodedMessage");
    if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
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
