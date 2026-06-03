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
  static const String _defaultUnit = 'kg';

  bool _isProcessing = false;
  bool _isUploading = false;
  bool _autoUploadAfterImport = true;

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
        _drafts.addAll(_parsePriceDrafts(recognizedText, image.name));
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

  List<_PriceDraft> _parsePriceDrafts(
    RecognizedText recognizedText,
    String fileName,
  ) {
    final layoutDrafts = _parseLayoutTablePriceDrafts(recognizedText, fileName);
    if (layoutDrafts.isNotEmpty) return layoutDrafts;

    final text = recognizedText.text;
    final tableDrafts = _parseTablePriceDrafts(text, fileName);
    if (tableDrafts.isNotEmpty) return tableDrafts;

    final date = _extractDate(text);
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.length > 4 && RegExp(r'\d').hasMatch(line));

    return lines
        .map((line) {
          if (date == null) return null;

          final price = _extractPrice(line);
          if (price == null) return null;

          final district = _detectDistrict(line);
          if (district == null) return null;

          final cropName = _extractCropName(line, district, price);
          if (cropName.length < 2) return null;

          return _PriceDraft(
            date: date,
            cropName: cropName,
            price: price,
            unit: _defaultUnit,
            marketName: district,
            district: district,
            sourceImage: fileName,
            sourceLine: line,
          );
        })
        .whereType<_PriceDraft>()
        .toList();
  }

  List<_PriceDraft> _parseLayoutTablePriceDrafts(
    RecognizedText recognizedText,
    String fileName,
  ) {
    final date = _extractDate(recognizedText.text);
    if (date == null) return [];

    final ocrLines = <_OcrLine>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final box = line.boundingBox;
        if (text.isEmpty) continue;
        ocrLines.add(_OcrLine(text: text, box: box));
      }
    }
    if (ocrLines.isEmpty) return [];

    ocrLines.sort((a, b) {
      final yCompare = a.centerY.compareTo(b.centerY);
      return yCompare == 0 ? a.centerX.compareTo(b.centerX) : yCompare;
    });

    final footerY = ocrLines
        .where((line) => line.text.toLowerCase().contains('minimum farm gate'))
        .map((line) => line.box.top)
        .fold<double?>(
          null,
          (current, y) => current == null
              ? y
              : current < y
              ? current
              : y,
        );

    final commodityHeader = ocrLines
        .where((line) => line.text.toLowerCase().trim().contains('commodity'))
        .cast<_OcrLine?>()
        .firstWhere((line) => line != null, orElse: () => null);
    if (commodityHeader == null) return [];

    final headerY = commodityHeader.centerY;
    final locationHeaders =
        ocrLines
            .where((line) {
              if (footerY != null && line.centerY >= footerY) return false;
              if ((line.centerY - headerY).abs() > 80) return false;
              final district = _detectDistrict(line.text);
              return district != null && line.centerX > commodityHeader.centerX;
            })
            .map((line) => (district: _detectDistrict(line.text)!, line: line))
            .toList()
          ..sort((a, b) => a.line.centerX.compareTo(b.line.centerX));
    if (locationHeaders.isEmpty) return [];

    final firstLocationX = locationHeaders.first.line.box.left;
    final tableLines = ocrLines.where((line) {
      if (line.centerY <= headerY + 20) return false;
      if (footerY != null && line.centerY >= footerY) return false;
      return true;
    }).toList();

    final commodityLines = tableLines.where((line) {
      if (line.box.left >= firstLocationX) return false;
      if (_extractAmountCells(line.text).isNotEmpty) return false;
      if (_isIgnoredTableLine(
        line.text,
        locationHeaders.map((h) => h.district).toList(),
      )) {
        return false;
      }
      final commodity = _extractTableCommodity(
        line.text,
        locationHeaders.map((h) => h.district).toList(),
      );
      return commodity.isNotEmpty;
    }).toList()..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (commodityLines.isEmpty) return [];

    final amountLines = tableLines
        .where((line) => line.box.left >= firstLocationX - 20)
        .toList();
    final drafts = <_PriceDraft>[];

    for (final commodityLine in commodityLines) {
      final commodity = _extractTableCommodity(
        commodityLine.text,
        locationHeaders.map((h) => h.district).toList(),
      );
      if (commodity.isEmpty) continue;

      for (final header in locationHeaders) {
        final cell = _bestAmountCellForColumn(
          amountLines,
          header.line.centerX,
          commodityLine.centerY,
        );
        final amount = cell == null ? null : _amountCellValue(cell.text);

        drafts.add(
          _PriceDraft(
            date: date,
            cropName: commodity,
            price: amount?.toString() ?? 'No price',
            unit: _defaultUnit,
            marketName: header.district,
            district: header.district,
            sourceImage: fileName,
            sourceLine:
                '$commodity, ${header.district}, ${amount ?? 'No price'}',
            selected: amount != null,
          ),
        );
      }
    }

    return drafts;
  }

  _OcrLine? _bestAmountCellForColumn(
    List<_OcrLine> lines,
    double columnX,
    double rowY,
  ) {
    final candidates = lines.where((line) {
      if ((line.centerY - rowY).abs() > 45) return false;
      if ((line.centerX - columnX).abs() > 110) return false;
      return _amountCellValue(line.text) != null || _isNoPriceCell(line.text);
    }).toList();

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aScore = (a.centerY - rowY).abs() + (a.centerX - columnX).abs();
      final bScore = (b.centerY - rowY).abs() + (b.centerX - columnX).abs();
      return aScore.compareTo(bScore);
    });
    return candidates.first;
  }

  int? _amountCellValue(String text) {
    final cells = _extractAmountCells(text);
    for (final cell in cells) {
      if (cell != null) return cell;
    }
    return null;
  }

  bool _isNoPriceCell(String text) {
    return RegExp(r'^\s*[-\u2013\u2014]\s*$').hasMatch(text);
  }

  List<_PriceDraft> _parseTablePriceDrafts(String text, String fileName) {
    final date = _extractDate(text);
    if (date == null) return [];

    final tableText = text
        .split(RegExp(r'minimum\s+farm\s+gate\s+prices', caseSensitive: false))
        .first;

    final locations =
        _districts
            .map((district) {
              final match = RegExp(
                '\\b${RegExp.escape(district)}\\b',
                caseSensitive: false,
              ).firstMatch(tableText);
              return match == null
                  ? null
                  : (district: district, index: match.start);
            })
            .whereType<({String district, int index})>()
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    final orderedLocations = locations
        .map((location) => location.district)
        .toList();
    if (orderedLocations.isEmpty) return [];

    final drafts = <_PriceDraft>[];
    String? pendingCommodity;
    final pendingAmountCells = <int?>[];

    void addDrafts(String commodity, List<int?> amountCells) {
      for (
        var index = 0;
        index < amountCells.length && index < orderedLocations.length;
        index++
      ) {
        final amount = amountCells[index];

        drafts.add(
          _PriceDraft(
            date: date,
            cropName: commodity,
            price: amount?.toString() ?? 'No price',
            unit: _defaultUnit,
            marketName: orderedLocations[index],
            district: orderedLocations[index],
            sourceImage: fileName,
            sourceLine:
                '$commodity, ${orderedLocations[index]}, ${amount ?? 'No price'}',
            selected: amount != null,
          ),
        );
      }
    }

    final lines = tableText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (final line in lines) {
      if (_isIgnoredTableLine(line, orderedLocations)) continue;

      final amountCells = _extractAmountCells(line);
      final commodity = _extractTableCommodity(line, orderedLocations);

      if (amountCells.isEmpty) {
        if (commodity.isNotEmpty) {
          pendingCommodity = commodity;
          pendingAmountCells.clear();
        }
        continue;
      }

      if (commodity.isNotEmpty) {
        pendingCommodity = commodity;
        pendingAmountCells
          ..clear()
          ..addAll(amountCells);
      } else if (pendingCommodity != null) {
        pendingAmountCells.addAll(amountCells);
      }

      if (pendingCommodity == null || pendingAmountCells.isEmpty) continue;

      if (pendingAmountCells.length >= orderedLocations.length) {
        addDrafts(pendingCommodity, pendingAmountCells);
        pendingCommodity = null;
        pendingAmountCells.clear();
      }
    }

    return drafts;
  }

  bool _isIgnoredTableLine(String line, List<String> locations) {
    final lower = line.toLowerCase();
    if (_extractDate(line) != null) return true;
    if (lower.contains('ace prices')) return true;
    if (lower.contains('domestic market')) return true;
    if (lower.contains('indicative')) return true;
    if (lower.contains('mwk')) return true;
    if (lower.contains('commodity')) return true;
    if (lower.contains('minimum farm gate')) return true;
    if (lower.contains('aceafrica')) return true;
    if (lower.contains('receiving price updates')) return true;

    return locations.any((location) => lower == location.toLowerCase());
  }

  List<int?> _extractAmountCells(String line) {
    if (_extractDate(line) != null) return [];

    return RegExp(
      r'\b\d[\d,]*\b|(?<!\w)[-\u2013\u2014](?!\w)',
    ).allMatches(line).map((match) {
      final value = match.group(0);
      if (value == '-') return null;

      final number = _parseNumber(value);
      return number != null && number >= 50 ? number : null;
    }).toList();
  }

  String _extractTableCommodity(String line, List<String> locations) {
    var commodity = line
        .replaceAll(RegExp(r'\b\d[\d,]*\b'), ' ')
        .replaceAll(RegExp(r'[-\u2013\u2014]'), ' ')
        .replaceAll(RegExp(r'[:|,;]'), ' ');

    for (final location in locations) {
      commodity = commodity.replaceAll(
        RegExp('\\b${RegExp.escape(location)}\\b', caseSensitive: false),
        ' ',
      );
    }

    commodity = commodity
        .replaceAll(
          RegExp(
            r'\b(commodity|market|date|amount|price|prices|mwk|kg|dap)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (commodity.isEmpty) return '';
    return _titleCase(commodity);
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
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

  String? _extractDate(String line) {
    final numericMatch = RegExp(
      r'\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b',
    ).firstMatch(line);
    if (numericMatch != null) {
      final day = numericMatch.group(1)!.padLeft(2, '0');
      final month = numericMatch.group(2)!.padLeft(2, '0');
      final yearText = numericMatch.group(3)!;
      final year = yearText.length == 2 ? yearText : yearText.substring(2);

      return '$day/$month/$year';
    }

    final wordMatch = RegExp(
      r'\b(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (wordMatch == null) return null;

    final month = _monthNumber(wordMatch.group(2));
    if (month == null) return null;

    final day = wordMatch.group(1)!.padLeft(2, '0');
    final yearText = wordMatch.group(3)!;
    final year = yearText.length == 2 ? yearText : yearText.substring(2);

    return '$day/$month/$year';
  }

  String? _monthNumber(String? value) {
    final month = value?.toLowerCase();
    const months = {
      'jan': '01',
      'january': '01',
      'feb': '02',
      'february': '02',
      'mar': '03',
      'march': '03',
      'apr': '04',
      'april': '04',
      'may': '05',
      'jun': '06',
      'june': '06',
      'jul': '07',
      'july': '07',
      'aug': '08',
      'august': '08',
      'sep': '09',
      'sept': '09',
      'september': '09',
      'oct': '10',
      'october': '10',
      'nov': '11',
      'november': '11',
      'dec': '12',
      'december': '12',
    };

    return months[month];
  }

  DateTime? _parseDraftDate(String value) {
    final match = RegExp(
      r'^(\d{2})\/(\d{2})\/(\d{2}|\d{4})$',
    ).firstMatch(value);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final yearText = match.group(3)!;
    final year = int.tryParse(yearText.length == 2 ? '20$yearText' : yearText);
    if (day == null || month == null || year == null) return null;

    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    return date;
  }

  String _extractCropName(String line, String district, String price) {
    var crop = line
        .replaceAll(RegExp(r'\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b'), ' ')
        .replaceAll(
          RegExp('\\b${RegExp.escape(district)}\\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp('\\b${RegExp.escape(price)}\\b'), ' ')
        .replaceAll(
          RegExp('\\b${RegExp.escape(price.replaceAll(',', ''))}\\b'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b(MWK|MK|K|price|prices|in|per)\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'[:|,;]'), ' ');

    crop = crop
        .replaceAll(
          RegExp(
            r'\b(kg|bag|pail|small|large|market|date|commodity|location|amount)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\d[\d,]*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (crop.isEmpty) return '';
    return _titleCase(crop);
  }

  String? _detectDistrict(String line) {
    for (final district in _districts) {
      if (RegExp('\\b$district\\b', caseSensitive: false).hasMatch(line)) {
        return district;
      }
    }
    return null;
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
              draft.date.trim().isNotEmpty &&
              draft.cropName.trim().isNotEmpty &&
              draft.price.trim().isNotEmpty &&
              _parseDraftDate(draft.date.trim()) != null &&
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
        final priceDate = _parseDraftDate(draft.date.trim())!;
        final priceTimestamp = Timestamp.fromDate(priceDate);

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
          'priceDate': priceTimestamp,
          'priceDateText': draft.date.trim(),
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
          'submittedAt': priceTimestamp,
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
                _PriceDraftCard(draft: draft, onChanged: () => setState(() {})),
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
  final VoidCallback onChanged;

  const _PriceDraftCard({required this.draft, required this.onChanged});

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
              initialValue: draft.date,
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => draft.date = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: draft.cropName,
              decoration: const InputDecoration(
                labelText: 'Commodity',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => draft.cropName = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: draft.district,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                draft.district = value;
                draft.marketName = value;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: draft.price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (MK)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => draft.price = value,
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

class _OcrLine {
  final String text;
  final Rect box;

  const _OcrLine({required this.text, required this.box});

  double get centerX => box.left + (box.width / 2);
  double get centerY => box.top + (box.height / 2);
}

class _PriceDraft {
  String date;
  String cropName;
  String price;
  String unit;
  String marketName;
  String district;
  final String sourceImage;
  final String sourceLine;
  bool selected;

  _PriceDraft({
    required this.date,
    required this.cropName,
    required this.price,
    required this.unit,
    required this.marketName,
    required this.district,
    required this.sourceImage,
    required this.sourceLine,
    this.selected = true,
  });
}
