import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';

class EditPricePage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditPricePage({
    super.key,
    required this.docId,
    required this.initialData,
  });

  @override
  State<EditPricePage> createState() => _EditPricePageState();
}

class _EditPricePageState extends State<EditPricePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _marketController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;

  late String _selectedCrop;
  late String _selectedUnit;
  late String _selectedDistrict;
  bool _isLoading = false;

  final List<String> _crops = [
    'Maize',
    'Beans',
    'Rice',
    'Soybeans',
    'Groundnuts',
    'Tobacco',
  ];
  final List<String> _units = [
    'kg',
    '50kg bag',
    'Pail (Small)',
    'Pail (Large)',
  ];
  final List<String> _districts = [
    'Lilongwe',
    'Blantyre',
    'Mzuzu',
    'Zomba',
    'Dedza',
    'Kasungu',
    'Mangochi',
    'Salima',
    'Thyolo',
    'Mulanje',
  ];

  @override
  void initState() {
    super.initState();
    _marketController = TextEditingController(
      text: widget.initialData['market'],
    );
    _priceController = TextEditingController(text: widget.initialData['price']);
    _notesController = TextEditingController(text: widget.initialData['notes']);
    _selectedCrop = widget.initialData['cropName'] ?? 'Maize';
    _selectedUnit = widget.initialData['unit'] ?? 'kg';
    _selectedDistrict = widget.initialData['district'] ?? 'Lilongwe';
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedData = {
        'cropName': _selectedCrop,
        'price': _priceController.text.trim(),
        'unit': _selectedUnit,
        'market': _marketController.text.trim(),
        'district': _selectedDistrict,
        'notes': _notesController.text.trim(),
        // Reset status to pending if it was approved?
        // User didn't specify, but usually edits require re-approval.
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService().updateData('prices', widget.docId, updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price updated successfully! Re-approval required.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Price Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _crops.contains(_selectedCrop)
                    ? _selectedCrop
                    : _crops.first,
                decoration: const InputDecoration(
                  labelText: 'Crop Name',
                  prefixIcon: Icon(Icons.grass),
                  border: OutlineInputBorder(),
                ),
                items: _crops
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCrop = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (MK)',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Enter price' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _units.contains(_selectedUnit)
                    ? _selectedUnit
                    : _units.first,
                decoration: const InputDecoration(
                  labelText: 'Measurement Unit',
                  prefixIcon: Icon(Icons.scale),
                  border: OutlineInputBorder(),
                ),
                items: _units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedUnit = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _marketController,
                decoration: const InputDecoration(
                  labelText: 'Market Name',
                  prefixIcon: Icon(Icons.storefront),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter market name'
                    : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _districts.contains(_selectedDistrict)
                    ? _selectedDistrict
                    : _districts.first,
                decoration: const InputDecoration(
                  labelText: 'District',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _districts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedDistrict = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleUpdate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'UPDATE PRICE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _marketController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
