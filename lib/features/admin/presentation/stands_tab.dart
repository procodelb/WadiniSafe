import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wadinisafe/features/admin/presentation/assign_drivers_dialog.dart';
import 'package:wadinisafe/features/admin/presentation/stands_dialog.dart';

final standsProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('stands').snapshots();
});

final driversProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('drivers').snapshots();
});

class StandsTab extends ConsumerWidget {
  const StandsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stands = ref.watch(standsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const StandDialog(),
        ),
      ),
      body: stands.when(
        data: (snapshot) {
          final validDocs = snapshot.docs.where((doc) {
            try {
              final data = doc.data();
              return data is Map<String, dynamic> &&
                  data['name'] is Map<String, dynamic> &&
                  data['capacity'] != null &&
                  data['type'] != null;
            } catch (_) {
              return false;
            }
          }).toList();

          return ListView(
            children: validDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final nameMap = data['name'] as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text(
                    nameMap['en'] ?? '—',
                  ),
                  subtitle: Text(
                    'Capacity: ${data['capacity']} | ${data['type']}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.people),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AssignDriversDialog(standId: doc.id),
                    ),
                  ),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => StandDialog(
                      standId: doc.id,
                      initialData: data,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
