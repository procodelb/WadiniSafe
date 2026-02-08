import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wadinisafe/features/admin/presentation/stands_tab.dart';

class AssignDriversDialog extends ConsumerWidget {
  final String standId;
  const AssignDriversDialog({required this.standId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(driversProvider);

    return AlertDialog(
      title: const Text('Assign Drivers'),
      content: drivers.when(
        data: (snapshot) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: snapshot.docs.map((d) {
              final isAssigned = d['standId'] == standId;
              return CheckboxListTile(
                title: Text(d['name'] ?? d.id),
                value: isAssigned,
                onChanged: (v) async {
                  final driverRef = FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(d.id);
                  final standDriverRef = FirebaseFirestore.instance
                      .collection('stands')
                      .doc(standId)
                      .collection('drivers')
                      .doc(d.id);

                  if (v == true) {
                    await driverRef.update({'standId': standId});
                    await standDriverRef
                        .set({'assignedAt': FieldValue.serverTimestamp()});
                  } else {
                    await driverRef.update({'standId': null});
                    await standDriverRef.delete();
                  }
                },
              );
            }).toList(),
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text(e.toString()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
