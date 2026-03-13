import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A badge that shows a real-time count of overdue notifications
/// (pending follow-ups + pending college visits) for [userId].
/// Updates automatically whenever Firestore data changes.
class NotificationBadge extends StatelessWidget {
  final String userId;
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;
  const NotificationBadge({
    Key? key,
    required this.userId,
    required this.child,
    this.badgeColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _notificationCountStream(userId),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Combines live Firestore counts for overdue follow-ups and college visits.
  static Stream<int> _notificationCountStream(String userId) {
    final now = Timestamp.fromDate(DateTime.now());
    final db = FirebaseFirestore.instance;

    final followUpsStream = db
        .collection('follow_ups')
        .where('createdBy', isEqualTo: userId)
        .where('followUpDate', isLessThan: now)
        .where('status', whereIn: ['pending', 'scheduled'])
        .snapshots()
        .map((s) => s.docs.length);

    final visitsStream = db
        .collection('college_visits')
        .where('createdBy', isEqualTo: userId)
        .where('visitDate', isLessThan: now)
        .where('status', whereIn: ['pending', 'scheduled'])
        .snapshots()
        .map((s) => s.docs.length);

    return _combineSum(followUpsStream, visitsStream);
  }

  /// Merges two int-streams and emits their sum whenever either emits.
  static Stream<int> _combineSum(Stream<int> a, Stream<int> b) {
    late StreamController<int> controller;
    StreamSubscription<int>? subA;
    StreamSubscription<int>? subB;
    int countA = 0;
    int countB = 0;

    controller = StreamController<int>(
      onListen: () {
        subA = a.listen(
          (val) {
            countA = val;
            if (!controller.isClosed) controller.add(countA + countB);
          },
          onError: (e) { if (!controller.isClosed) controller.addError(e); },
        );
        subB = b.listen(
          (val) {
            countB = val;
            if (!controller.isClosed) controller.add(countA + countB);
          },
          onError: (e) { if (!controller.isClosed) controller.addError(e); },
        );
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
      },
    );

    return controller.stream;
  }
}
