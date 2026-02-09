import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final pricingProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('pricing').snapshots();
});

final areasProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance.collection('areas').snapshots();
});

class PricingTab extends ConsumerWidget {
  const PricingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricing = ref.watch(pricingProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const PricingDialog(),
        ),
      ),
      body: pricing.when(
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(child: Text('No pricing rules'));
          }

          return ListView.builder(
            itemCount: snapshot.docs.length,
            itemBuilder: (_, i) {
              final doc = snapshot.docs[i];
              final data = doc.data();

              // Skip invalid documents
              if (data is! Map<String, dynamic> ||
                  data['prices'] is! Map<String, dynamic> ||
                  data['fromAreaId'] == null ||
                  data['toAreaId'] == null) {
                return const SizedBox.shrink();
              }

              final prices = data['prices'] as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text(
                    '${data['fromAreaId']} → ${data['toAreaId']} (${data['vehicleType']})',
                  ),
                  subtitle: Text(
                    'Base: ${prices['baseLBP']} LBP / ${prices['baseUSD']} USD',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => PricingDialog(
                            pricingId: doc.id,
                            initialData: data,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => doc.reference.delete(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}

class PricingDialog extends ConsumerStatefulWidget {
  final String? pricingId;
  final Map<String, dynamic>? initialData;

  const PricingDialog({this.pricingId, this.initialData, super.key});

  @override
  ConsumerState<PricingDialog> createState() => _PricingDialogState();
}

class _PricingDialogState extends ConsumerState<PricingDialog> {
  String? fromAreaId;
  String? toAreaId;
  String vehicleType = 'taxi';

  final baseLBP = TextEditingController();
  final baseUSD = TextEditingController();
  final perKmLBP = TextEditingController();
  final perKmUSD = TextEditingController();
  final perMinuteLBP = TextEditingController();
  final perMinuteUSD = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      fromAreaId = d['fromAreaId'];
      toAreaId = d['toAreaId'];
      vehicleType = d['vehicleType'];
      baseLBP.text = d['prices']['baseLBP'].toString();
      baseUSD.text = d['prices']['baseUSD'].toString();
      perKmLBP.text = d['prices']['perKmLBP'].toString();
      perKmUSD.text = d['prices']['perKmUSD'].toString();
      perMinuteLBP.text = d['prices']['perMinuteLBP'].toString();
      perMinuteUSD.text = d['prices']['perMinuteUSD'].toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasProvider);

    return AlertDialog(
      title: Text(widget.pricingId == null ? 'Add Pricing' : 'Edit Pricing'),
      content: areas.when(
        data: (snapshot) {
          return SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField(
                  value: fromAreaId,
                  hint: const Text('From Area'),
                  items: snapshot.docs
                      .map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d['name']['en']),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => fromAreaId = v),
                ),
                DropdownButtonFormField(
                  value: toAreaId,
                  hint: const Text('To Area'),
                  items: snapshot.docs
                      .map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d['name']['en']),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => toAreaId = v),
                ),
                DropdownButtonFormField(
                  value: vehicleType,
                  items: const [
                    DropdownMenuItem(value: 'taxi', child: Text('Taxi')),
                    DropdownMenuItem(value: 'bus', child: Text('Bus')),
                  ],
                  onChanged: (v) => setState(() => vehicleType = v!),
                ),
                _numField('Base LBP', baseLBP),
                _numField('Base USD', baseUSD),
                _numField('Per KM LBP', perKmLBP),
                _numField('Per KM USD', perKmUSD),
                _numField('Per Minute LBP', perMinuteLBP),
                _numField('Per Minute USD', perMinuteUSD),
              ],
            ),
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text(e.toString()),
      ),
      actions: [
        TextButton(
            onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _numField(String label, TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _save() async {
    final data = {
      'fromAreaId': fromAreaId,
      'toAreaId': toAreaId,
      'vehicleType': vehicleType,
      'prices': {
        'baseLBP': num.parse(baseLBP.text),
        'baseUSD': num.parse(baseUSD.text),
        'perKmLBP': num.parse(perKmLBP.text),
        'perKmUSD': num.parse(perKmUSD.text),
        'perMinuteLBP': num.parse(perMinuteLBP.text),
        'perMinuteUSD': num.parse(perMinuteUSD.text),
      }
    };

    final ref = FirebaseFirestore.instance.collection('pricing');

    if (widget.pricingId == null) {
      await ref.add(data);
    } else {
      await ref.doc(widget.pricingId).update(data);
    }

    Navigator.pop(context);
  }
}
