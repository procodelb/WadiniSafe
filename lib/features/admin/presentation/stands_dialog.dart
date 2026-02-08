import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StandDialog extends ConsumerStatefulWidget {
  final String? standId;
  final Map<String, dynamic>? initialData;

  const StandDialog({
    this.standId,
    this.initialData,
    super.key,
  });

  @override
  ConsumerState<StandDialog> createState() => _StandDialogState();
}

class _StandDialogState extends ConsumerState<StandDialog> {
  final nameEn = TextEditingController();
  final nameAr = TextEditingController();
  final capacity = TextEditingController();
  final lat = TextEditingController();
  final lng = TextEditingController();
  final geohash = TextEditingController();

  String type = 'taxi_stand';

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      nameEn.text = d['name']['en'];
      nameAr.text = d['name']['ar'];
      capacity.text = d['capacity'].toString();
      type = d['type'];
      lat.text = d['location']['lat'].toString();
      lng.text = d['location']['lng'].toString();
      geohash.text = d['location']['geohash'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.standId == null ? 'Create Stand' : 'Edit Stand'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: nameEn,
              decoration: const InputDecoration(labelText: 'Name (EN)'),
            ),
            TextField(
              controller: nameAr,
              decoration: const InputDecoration(labelText: 'Name (AR)'),
            ),
            DropdownButtonFormField(
              value: type,
              decoration: const InputDecoration(labelText: 'Stand Type'),
              items: const [
                DropdownMenuItem(
                  value: 'taxi_stand',
                  child: Text('Taxi Stand'),
                ),
                DropdownMenuItem(
                  value: 'bus_stop',
                  child: Text('Bus Stop'),
                ),
              ],
              onChanged: (v) => setState(() => type = v!),
            ),
            TextField(
              controller: capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
            const Divider(height: 24),
            TextField(
              controller: lat,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            TextField(
              controller: lng,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
            TextField(
              controller: geohash,
              decoration: const InputDecoration(labelText: 'Geohash'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final data = {
      'name': {
        'en': nameEn.text.trim(),
        'ar': nameAr.text.trim(),
      },
      'capacity': int.parse(capacity.text),
      'type': type,
      'location': {
        'lat': double.parse(lat.text),
        'lng': double.parse(lng.text),
        'geohash': geohash.text.trim(),
      },
    };

    final ref = FirebaseFirestore.instance.collection('stands');

    if (widget.standId == null) {
      await ref.add(data);
    } else {
      await ref.doc(widget.standId).update(data);
    }

    Navigator.pop(context);
  }
}
