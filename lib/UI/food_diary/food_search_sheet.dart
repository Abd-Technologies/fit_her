import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/food_db_service.dart';
import '../../theme/app_colors.dart';

Future<FoodItem?> showFoodSearchSheet(BuildContext context) {
  return showModalBottomSheet<FoodItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _FoodSearchSheet(),
  );
}

class _FoodSearchSheet extends StatefulWidget {
  const _FoodSearchSheet();

  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> {
  final _controller = TextEditingController();
  List<FoodItem> _results = [];

  @override
  void initState() {
    super.initState();
    _results = Get.find<FoodDbService>().foods.take(20).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    setState(() {
      _results = Get.find<FoodDbService>().search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8EDD4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: _onQuery,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search English or Roman Urdu…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD8EDD4)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final f = _results[i];
                  return ListTile(
                    title: Text(
                      f.nameEn,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${f.nameRoman} · ${f.serving} · ${f.calories} kcal',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                    ),
                    trailing: Icon(Icons.add, color: AppColors.primaryDeep),
                    onTap: () => Navigator.pop(context, f),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
