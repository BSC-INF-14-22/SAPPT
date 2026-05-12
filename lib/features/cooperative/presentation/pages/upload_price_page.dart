// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';

class UploadPricePage extends StatefulWidget {
  const UploadPricePage({super.key});

  @override
  State<UploadPricePage> createState() => _UploadPricePageState();
}

class _UploadPricePageState extends State<UploadPricePage> {
  final _formKey = GlobalKey<FormState>();
  final _cropController = TextEditingController();
  final _marketController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedUnit = 'kg';
  String _selectedDistrict = 'Lilongwe';
  bool _isLoading = false;

  final List<String> _units = [
    'kg',
    '50kg bag',
    'Pail (Small)',
    'Pail (Large)',
  ];
  final List<String> _districts = [
    "Balaka",
    "Blantyre",
    "Chikwawa",
    "Chiradzulu",
    "Chitipa",
    "Dedza",
    "Dowa",
    "Karonga",
    "Kasungu",
    "Likoma",
    "Lilongwe",
    "Machinga",
    "Mangochi",
    "Mchinji",
    "Mulanje",
    "Mwanza",
    "Mzimba",
    "Neno",
    "Nkhata Bay",
    "Nkhotakota",
    "Nsanje",
    "Ntcheu",
    "Ntchisi",
    "Phalombe",
    "Rumphi",
    "Salima",
    "Thyolo",
    "Zomba",
  ];

  Future<void> _handleSubmit() async {
    final cropName = _cropController.text.trim();
    if (!_formKey.currentState!.validate()) return;
    if (cropName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a crop'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = AuthService().currentUser;
      if (user == null)
        // ignore: curly_braces_in_flow_control_structures
        throw Exception('You must be logged in to upload prices.');

      // 1. Check if the crop exists in 'products', if not, add it immediately
      final productQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: cropName)
          .get();

      if (productQuery.docs.isEmpty) {
        await FirestoreService().addData('products', {
          'name': cropName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Submit the price entry
      final priceData = {
        'cropName': cropName,
        'price': _priceController.text.trim(),
        'unit': _selectedUnit,
        'market': _marketController.text.trim(),
        'district': _selectedDistrict,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'uploadedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService().addData('prices', priceData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price uploaded successfully! Crop added if new.'),
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
      appBar: AppBar(title: const Text('Upload New Price')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Crop Input (Autocomplete + Auto-Add)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, snapshot) {
                  final productNames =
                      snapshot.data?.docs
                          .map((d) => d.data()['name'] as String)
                          .toList() ??
                      [];

                  return Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return productNames.where((String option) {
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
                      });
                    },
                    onSelected: (String selection) {
                      _cropController.text = selection;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          // Sync the field controller with our state controller
                          if (_cropController.text != controller.text &&
                              _cropController.text.isNotEmpty) {
                            controller.text = _cropController.text;
                          }
                          controller.addListener(() {
                            _cropController.text = controller.text;
                          });

                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Crop Name',
                              hintText: 'Type to search or add new',
                              prefixIcon: Icon(Icons.grass),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Enter or select a crop'
                                : null,
                          );
                        },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Price Field
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (MK)',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'e.g. 500',
                ),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter the current price'
                    : null,
              ),
              const SizedBox(height: 16),

              // Unit Dropdown
              DropdownButtonFormField<String>(
                value: _selectedUnit,
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

              // Market Field
              TextFormField(
                controller: _marketController,
                decoration: const InputDecoration(
                  labelText: 'Market Name',
                  prefixIcon: Icon(Icons.storefront),
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Lilongwe Central Market',
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter the market name'
                    : null,
              ),
              const SizedBox(height: 16),

              // District Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDistrict,
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

              // Notes Field
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'e.g. High supply today',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SUBMIT PRICE',
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
