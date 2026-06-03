import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsappMarketImportPage extends StatefulWidget {
  const WhatsappMarketImportPage({super.key});

  @override
  State<WhatsappMarketImportPage> createState() =>
      _WhatsappMarketImportPageState();
}

class _WhatsappMarketImportPageState extends State<WhatsappMarketImportPage> {
  static final Uri _channelUri = Uri.parse(
    'https://whatsapp.com/channel/0029VbDHIyM9xVJjxK8xyD03',
  );

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final List<_OcrResult> _results = [];
  final List<_PriceDraft> _drafts = [];

  bool _isProcessing = false;
  bool _isUploading = false;
  bool _autoUploadAfterImport = true;

  final List<String> _units = const [
    'kg',
    '50kg bag',
    'Pail (Small)',
    'Pail (Large)',
  ];

  final List<String> _districts = const [
    'Chitipa',
    'Karonga',
    'Likoma',
    'Mzimba',
    'Nkhata Bay',
    'Rumphi',
    'Dedza',
    'Dowa',
    'Kasungu',
    'Lilongwe',
    'Mchinji',
    'Nkhotakota',
    'Ntchisi',
    'Salima',
    'Balaka',
    'Blantyre',
    'Chikwawa',
    'Chiradzulu',
    'Machinga',
    'Mangochi',
    'Mulanje',
    'Mwanza',
    'Neno',
    'Ntcheu',
    'Nsanje',
    'Phalombe',
    'Thyolo',
    'Zomba',
  ];

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _openChannel() async {
    final opened = await launchUrl(
      _channelUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the WhatsApp Channel.')),
      );
    }
  }

  Future<void> _pickAndReadImages() async {
    final pickedImages = await _picker.pickMultiImage();
    final topThreeImages = pickedImages.take(3).toList();

    if (topThreeImages.isEmpty) return;
    var processedSuccessfully = false;

    setState(() {
      _isProcessing = true;
      _results.clear();
      _drafts.clear();
    });

    try {
      for (final image in topThreeImages) {
        final inputImage = InputImage.fromFilePath(image.path);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        _results.add(
          _OcrResult(fileName: image.name, text: recognizedText.text.trim()),
        );
        _drafts.addAll(_parsePriceDrafts(recognizedText.text, image.name));
      }

      processedSuccessfully = true;

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read selected images: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }

    if (processedSuccessfully && mounted && _autoUploadAfterImport) {
      await _uploadSelectedDrafts(
        emptyMessage: 'No valid price rows were detected for upload.',
      );
    }
  }

  Future<void> _copyAllText() async {
    final text = _results
        .map((result) => '${result.fileName}\n${result.text}')
        .join('\n\n---\n\n');

    if (text.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Extracted text copied.')));
    }
  }

  List<_PriceDraft> _parsePriceDrafts(String text, String fileName) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.length > 4 && RegExp(r'\d').hasMatch(line));

    return lines
        .map((line) {
          final price = _extractPrice(line);
          if (price == null) return null;

          final cropName = _extractCropName(line);
          if (cropName.length < 2) return null;

          final district = _detectDistrict(line) ?? 'Lilongwe';
          final unit = _detectUnit(line);

          return _PriceDraft(
            cropName: cropName,
            price: price,
            unit: unit,
            marketName: district,
            district: district,
            sourceImage: fileName,
            sourceLine: line,
          );
        })
        .whereType<_PriceDraft>()
        .toList();
  }

  String? _extractPrice(String line) {
    final rangeMatch = RegExp(
      r'(\d[\d,]*)\s*(?:-|to)\s*(\d[\d,]*)',
      caseSensitive: false,
    ).firstMatch(line);

    if (rangeMatch != null) {
      final min = _parseNumber(rangeMatch.group(1));
      final max = _parseNumber(rangeMatch.group(2));
      if (min != null && max != null) {
        final average = ((min + max) / 2).round();
        return average.toString();
      }
    }

    final numbers = RegExp(r'\d[\d,]*')
        .allMatches(line)
        .map((match) => _parseNumber(match.group(0)))
        .whereType<int>()
        .where((number) => number >= 50)
        .toList();

    if (numbers.isEmpty) return null;
    return numbers.last.toString();
  }

  int? _parseNumber(String? value) {
    if (value == null) return null;
    return int.tryParse(value.replaceAll(',', ''));
  }

  String _extractCropName(String line) {
    final firstNumber = RegExp(r'\d').firstMatch(line);
    final beforePrice = firstNumber == null
        ? line
        : line.substring(0, firstNumber.start);

    var crop = beforePrice
        .replaceAll(
          RegExp(r'\b(MWK|MK|K|price|prices|in|per)\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'[:|,;]'), ' ');

    for (final district in _districts) {
      crop = crop.replaceAll(
        RegExp('\\b$district\\b', caseSensitive: false),
        ' ',
      );
    }

    crop = crop
        .replaceAll(
          RegExp(r'\b(kg|bag|pail|small|large)\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (crop.isEmpty) return '';
    return crop
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String? _detectDistrict(String line) {
    for (final district in _districts) {
      if (RegExp('\\b$district\\b', caseSensitive: false).hasMatch(line)) {
        return district;
      }
    }
    return null;
  }

  String _detectUnit(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('50kg')) return '50kg bag';
    if (lower.contains('large pail')) return 'Pail (Large)';
    if (lower.contains('small pail')) return 'Pail (Small)';
    return 'kg';
  }

  String _slugify(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'unknown' : slug;
  }

  Future<void> _uploadSelectedDrafts({
    String emptyMessage = 'Select at least one valid price row.',
  }) async {
    final selectedDrafts = _drafts
        .where(
          (draft) =>
              draft.selected &&
              draft.cropName.trim().isNotEmpty &&
              draft.price.trim().isNotEmpty &&
              _parseNumber(draft.price.trim()) != null,
        )
        .toList();

    if (selectedDrafts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(emptyMessage)));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = AuthService().currentUser;
      if (user == null) {
        throw Exception('You must be logged in to upload prices.');
      }

      final userData = await FirestoreService().getUserByUid(user.uid);
      final cooperativeName =
          (userData?['fullName'] ?? user.displayName ?? 'Cooperative Officer')
              .toString()
              .trim();

      for (final draft in selectedDrafts) {
        final cropName = draft.cropName.trim();
        final marketName = draft.marketName.trim().isEmpty
            ? draft.district
            : draft.marketName.trim();
        final productId = _slugify(cropName);
        final marketId = _slugify('$marketName ${draft.district}');
        final price = _parseNumber(draft.price.trim())!;

        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .set({
              'name': cropName,
              'cropName': cropName,
              'unit': draft.unit,
              'measurementUnit': draft.unit,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('commodities')
            .doc(productId)
            .set({
              'name': cropName,
              'cropName': cropName,
              'unit': draft.unit,
              'measurementUnit': draft.unit,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('markets')
            .doc(marketId)
            .set({
              'name': marketName,
              'marketName': marketName,
              'district': draft.district,
              'region': draft.district,
              'location': draft.district,
              'isActive': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        await FirestoreService().addData('prices', {
          'cropName': cropName,
          'productName': cropName,
          'price': price,
          'unit': draft.unit,
          'market': marketName,
          'marketName': marketName,
          'marketId': marketId,
          'district': draft.district,
          'notes':
              'Auto-imported from WhatsApp Channel OCR. Source image: ${draft.sourceImage}',
          'status': 'pending',
          'uploadedBy': user.uid,
          'cooperativeName': cooperativeName,
          'uploadedByName': cooperativeName,
          'cooperativeEmail': user.email,
          'sourceType': 'whatsapp_channel_ocr',
          'sourceName': 'WhatsApp Market Channel',
          'sourceUrl': _channelUri.toString(),
          'sourceImage': draft.sourceImage,
          'sourceRawText': draft.sourceLine,
          'submittedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        for (final draft in selectedDrafts) {
          draft.selected = false;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedDrafts.length} price(s) uploaded.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Market Import')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: theme.primaryColor.withAlpha(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'How this works',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'WhatsApp Channels do not provide an official public feed '
                      'for apps to auto-download posts. Open the channel, save '
                      'the latest 3 price-table pictures, then select them here '
                      'to extract text for review and upload.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ActionButton(
              label: 'Open WhatsApp Channel',
              icon: Icons.chat_outlined,
              onPressed: _openChannel,
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: _autoUploadAfterImport
                  ? 'Select Pictures & Auto Upload'
                  : 'Select Saved Top 3 Pictures',
              icon: Icons.image_search_outlined,
              onPressed: _isProcessing ? null : _pickAndReadImages,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoUploadAfterImport,
              title: const Text('Auto-upload after image import'),
              subtitle: const Text(
                'Detected valid price rows are submitted immediately.',
              ),
              onChanged: _isProcessing || _isUploading
                  ? null
                  : (value) => setState(() => _autoUploadAfterImport = value),
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'Go to Upload Prices',
              icon: Icons.cloud_upload_outlined,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRouter.uploadPrice),
            ),
            const SizedBox(height: 24),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_results.isEmpty)
              const Text('No pictures processed yet.')
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Extracted Text',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyAllText,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final result in _results) _OcrResultCard(result: result),
            ],
            if (_drafts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Detected Price Rows',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _autoUploadAfterImport
                    ? 'Valid rows are uploaded automatically after import. You can turn this off to review OCR first.'
                    : 'Review each row before uploading. OCR can misread table text.',
              ),
              const SizedBox(height: 12),
              for (final draft in _drafts)
                _PriceDraftCard(
                  draft: draft,
                  units: _units,
                  districts: _districts,
                  onChanged: () => setState(() {}),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _uploadSelectedDrafts(),
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Upload Selected Prices',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceDraftCard extends StatelessWidget {
  final _PriceDraft draft;
  final List<String> units;
  final List<String> districts;
  final VoidCallback onChanged;

  const _PriceDraftCard({
    required this.draft,
    required this.units,
    required this.districts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.selected,
              title: Text('Source: ${draft.sourceImage}'),
              subtitle: Text(draft.sourceLine),
              onChanged: (value) {
                draft.selected = value ?? true;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: draft.cropName,
              decoration: const InputDecoration(
                labelText: 'Crop Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => draft.cropName = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: draft.price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (MK)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => draft.price = value,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: units.contains(draft.unit)
                  ? draft.unit
                  : units.first,
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
              ),
              items: units
                  .map(
                    (unit) => DropdownMenuItem(value: unit, child: Text(unit)),
                  )
                  .toList(),
              onChanged: (value) {
                draft.unit = value ?? units.first;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: draft.marketName,
              decoration: const InputDecoration(
                labelText: 'Market Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => draft.marketName = value,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: districts.contains(draft.district)
                  ? draft.district
                  : 'Lilongwe',
              decoration: const InputDecoration(
                labelText: 'District',
                border: OutlineInputBorder(),
              ),
              items: districts
                  .map(
                    (district) => DropdownMenuItem(
                      value: district,
                      child: Text(district),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                draft.district = value ?? 'Lilongwe';
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _OcrResultCard extends StatelessWidget {
  final _OcrResult result;

  const _OcrResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.fileName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              result.text.isEmpty ? 'No readable text found.' : result.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrResult {
  final String fileName;
  final String text;

  const _OcrResult({required this.fileName, required this.text});
}

class _PriceDraft {
  String cropName;
  String price;
  String unit;
  String marketName;
  String district;
  final String sourceImage;
  final String sourceLine;
  bool selected = true;

  _PriceDraft({
    required this.cropName,
    required this.price,
    required this.unit,
    required this.marketName,
    required this.district,
    required this.sourceImage,
    required this.sourceLine,
  });
}
