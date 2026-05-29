import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/services/language_service.dart';

class SearchPricesPage extends StatefulWidget {
  const SearchPricesPage({super.key});

  @override
  State<SearchPricesPage> createState() => _SearchPricesPageState();
}

class _SearchPricesPageState extends State<SearchPricesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedDistrict;
  bool _sortByLatest = true;

  final List<String> _districts = [
    'All',
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Market Prices')),
      body: Column(
        children: [
          _buildSearchAndFilters(theme),
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.primaryColor.withAlpha(10),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search crops (e.g. Maize, Beans)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
          const SizedBox(height: 12),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // District Filter
                _buildFilterChip(
                  label: _selectedDistrict ?? 'District',
                  icon: Icons.location_on_outlined,
                  onPressed: _showDistrictPicker,
                  isActive:
                      _selectedDistrict != null && _selectedDistrict != 'All',
                ),
                const SizedBox(width: 8),

                // Sort Toggle
                _buildFilterChip(
                  label: _sortByLatest ? 'Latest First' : 'Price: Low-High',
                  icon: Icons.sort_rounded,
                  onPressed: () =>
                      setState(() => _sortByLatest = !_sortByLatest),
                  isActive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isActive ? Colors.white : theme.primaryColor,
      ),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: isActive ? theme.primaryColor : Colors.white,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : theme.primaryColor,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.primaryColor.withAlpha(50)),
      ),
    );
  }

  void _showDistrictPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _districts.length,
            itemBuilder: (context, index) {
              final d = _districts[index];
              return ListTile(
                title: Text(d),
                trailing: _selectedDistrict == d
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedDistrict = d == 'All' ? null : d);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildResultsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, productsSnapshot) {
        if (productsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final registeredProducts =
            productsSnapshot.data?.docs
                .map((d) => d.data()['name'].toString().toLowerCase())
                .toSet() ??
            {};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService().getFilteredCollectionStream(
            'prices',
            'status',
            'approved',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            var docs = snapshot.data?.docs ?? [];
            final language = LanguageService.currentLanguage;

            // Apply Client-Side Filters
            var filteredList = docs.where((doc) {
              final data = doc.data();
              final cropName = (data['cropName'] ?? '').toString();
              final displayCropName = LanguageService.cropNameForLanguage(
                cropName,
                language,
              );
              final district = data['district'] ?? '';

              bool isRegistered = registeredProducts.contains(
                cropName.toLowerCase(),
              );
              bool matchesSearch = cropName.toLowerCase().contains(
                    _searchQuery,
                  ) ||
                  displayCropName.toLowerCase().contains(_searchQuery);
              bool matchesDistrict =
                  _selectedDistrict == null ||
                  _selectedDistrict == 'All' ||
                  district == _selectedDistrict;

              return isRegistered && matchesSearch && matchesDistrict;
            }).toList();

            // Sort
            filteredList.sort((a, b) {
              if (_sortByLatest) {
                final dateA = a.data()['updatedAt'];
                final dateB = b.data()['updatedAt'];
                DateTime? dtA = _parseDate(dateA);
                DateTime? dtB = _parseDate(dateB);
                if (dtA == null || dtB == null) return 0;
                return dtB.compareTo(dtA);
              } else {
                final priceA =
                    double.tryParse(a.data()['price']?.toString() ?? '0') ?? 0;
                final priceB =
                    double.tryParse(b.data()['price']?.toString() ?? '0') ?? 0;
                return priceA.compareTo(priceB);
              }
            });

            if (filteredList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    const Text('No crops found matching your criteria.'),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = filteredList[index].data();
                return _buildPriceCard(context, data);
              },
            );
          },
        );
      },
    );
  }

  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.tryParse(date);
    return null;
  }

  Widget _buildPriceCard(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final language = LanguageService.currentLanguage;
    final cropName = (data['cropName'] ?? 'Unknown Crop').toString();
    final displayCropName = LanguageService.cropNameForLanguage(
      cropName,
      language,
    );
    final price = data['price'] ?? '0';
    final unit = data['unit'] ?? 'kg';
    final market = data['market'] ?? 'Local Market';
    final district = data['district'] ?? 'Not Specified';

    String formattedDate = 'Just now';
    final dt = _parseDate(data['updatedAt']);
    if (dt != null) {
      formattedDate = DateFormat('MMM d, yyyy').format(dt);
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          displayCropName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$market, $district',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Updated: $formattedDate',
              style: const TextStyle(fontSize: 12),
            ),
            if (_cooperativeNameFromPrice(data) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'By: ${_cooperativeNameFromPrice(data)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.primaryColor,
                  ),
                ),
              )
            else if (data['uploadedBy'] != null)
              FutureBuilder<Map<String, dynamic>?>(
                future: FirestoreService().getUserByUid(data['uploadedBy']),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Text(
                      'Loading cooperative...',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    );
                  }
                  final coopName =
                      userSnapshot.data?['fullName'] ?? 'Unknown Cooperative';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'By: $coopName',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.primaryColor,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'MK $price',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '/ $unit',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String? _cooperativeNameFromPrice(Map<String, dynamic> price) {
    final value = price['cooperativeName'] ??
        price['uploadedByName'] ??
        price['cooperativeOfficerName'];
    if (value == null) return null;

    final name = value.toString().trim();
    return name.isEmpty ? null : name;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
