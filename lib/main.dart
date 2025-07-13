import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(home: MyHomePage());
}

class PageData {
  final IconData icon;
  final String title;

  const PageData({required this.icon, required this.title});
}

class FoodItem {
  final String name, imageUrl, ccdsUnit, searchKcal;

  const FoodItem({
    required this.name,
    required this.imageUrl,
    required this.ccdsUnit,
    required this.searchKcal,
  });
}

class SearchScreen extends StatefulWidget {
  final String mealType;
  const SearchScreen({super.key, required this.mealType});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _searchFoods(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = [];
    });

    try {
      final url = Uri.parse(
        'https://calorie.slism.jp/?searchWord=$query&search=検索',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final searchNo = document.querySelectorAll('input.searchNo');
        final searchNameVal = document.querySelectorAll('input.searchNameVal');
        final ccdsUnit = document.querySelectorAll('span.ccds_unit');
        final searchKcal = document.querySelectorAll('span.searchKcal');

        final results = <FoodItem>[];
        final minLength = [
          searchNo.length,
          searchNameVal.length,
          ccdsUnit.length,
          searchKcal.length,
        ].reduce((a, b) => a < b ? a : b);

        for (var i = 0; i < minLength; i++) {
          final noValue = searchNo[i].attributes['value'] ?? '';
          final name = searchNameVal[i].attributes['value'] ?? '';
          final unit = ccdsUnit[i].text ?? 'N/A';
          final kcal = searchKcal[i].text ?? 'N/A';

          if (noValue.isNotEmpty && name.isNotEmpty) {
            results.add(
              FoodItem(
                name: name,
                imageUrl:
                    'https://cdn.slism.jp/calorie/foodImages/$noValue.jpg',
                ccdsUnit: unit,
                searchKcal: kcal,
              ),
            );
          }
        }

        setState(() {
          _searchResults = results;
          _isLoading = false;
          if (results.isEmpty) _errorMessage = '検索結果が見つかりませんでした。';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'HTTPエラー: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'エラー: $e';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleFoodSelection(FoodItem food) {
    // 選択された食品をMyHomePageに返す
    Navigator.pop(context, food);
  }

  Widget buildFoodItemCard(FoodItem food, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _handleFoodSelection(food), // Make entire card clickable
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      food.name,
                      style: const TextStyle(fontSize: 20),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${food.searchKcal}kcal',
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: Image.network(
                          food.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.add_circle,
                        size: 30,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '単位: ${food.ccdsUnit}',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.mealType} 検索')),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '${widget.mealType}の食品を検索',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _errorMessage = null;
                  });
                },
              ),
            ),
            onSubmitted: _searchFoods,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: _searchResults.isEmpty && _errorMessage == null
                      ? const Center(child: Text('検索結果がありません'))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) =>
                              buildFoodItemCard(_searchResults[index], index),
                        ),
                ),
        ],
      ),
    ),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  static const _cardHeight = 100.0;
  static const _macroCardHeight = 200.0;
  static const _cardMargin = 10.0;
  static const _cardBorderRadius = BorderRadius.all(Radius.circular(10));
  static const _iconSize = 24.0;
  static const _proteinColor = Colors.blue;
  static const _carbColor = Colors.purple;
  static const _fatColor = Color.fromARGB(255, 255, 200, 0);

  final _pages = const [
    PageData(icon: Icons.add, title: '追加'),
    PageData(icon: Icons.query_stats, title: '履歴'),
    PageData(icon: Icons.settings, title: '設定'),
  ];

  double currentCalories = 1200, maxCalories = 2000;
  double proteinCurrent = 30, carbCurrent = 30, fatCurrent = 30;
  double proteinMax = 100, carbMax = 100, fatMax = 100;

  // 食事タイプごとの選択された食品を管理するリスト
  final Map<String, List<FoodItem>> _selectedFoods = {
    '朝食': [],
    '昼食': [],
    '夜食': [],
  };

  // Helper method to parse calories from text
  double _parseCalories(String kcalText) {
    // Remove any non-numeric characters except decimal point
    final cleanText = kcalText.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleanText) ?? 0.0;
  }

  List<PieChartSectionData> _getPieChartData() => [
    PieChartSectionData(
      value: currentCalories,
      color: _proteinColor,
      title: '',
      radius: 50,
    ),
    PieChartSectionData(
      value: maxCalories - currentCalories,
      color: Colors.grey.withOpacity(0.2),
      title: '',
      radius: 50,
    ),
  ];

  Widget _buildBarChart(
    double current,
    double max,
    Color color, {
    double height = 70,
    double width = 25,
  }) {
    final percentage = (current / max).clamp(0.0, 1.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: width,
            height: height * percentage,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(
    String label,
    double current,
    double max,
    Color color,
  ) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Icon(Icons.square_rounded, size: _iconSize, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
      Row(
        children: [
          Text(
            '${current.toInt()}',
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '/${max.toInt()}g',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    ],
  );

  Widget _buildCard(String? cardTitle, int index) {
    final isMacro = index == 0;
    final foods = isMacro ? [] : _selectedFoods[cardTitle] ?? [];
    final height = isMacro
        ? _macroCardHeight
        : _cardHeight + (foods.length * 60.0);
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Column(
          children: [
            if (cardTitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  cardTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isMacro)
              Container(
                margin: const EdgeInsets.all(_cardMargin),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${currentCalories.toInt()}',
                                  style: const TextStyle(fontSize: 30),
                                ),
                                Text(
                                  ' /${maxCalories.toInt()}kcal',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '残り${(maxCalories - currentCalories).toInt()}kcal',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildBarChart(
                              proteinCurrent,
                              proteinMax,
                              _proteinColor,
                            ),
                            const SizedBox(width: 3),
                            _buildBarChart(carbCurrent, carbMax, _carbColor),
                            const SizedBox(width: 3),
                            _buildBarChart(fatCurrent, fatMax, _fatColor),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMacroRow(
                      'タンパク質',
                      proteinCurrent,
                      proteinMax,
                      _proteinColor,
                    ),
                    const SizedBox(height: 8),
                    _buildMacroRow('炭水化物', carbCurrent, carbMax, _carbColor),
                    const SizedBox(height: 8),
                    _buildMacroRow('脂質', fatCurrent, fatMax, _fatColor),
                  ],
                ),
              )
            else ...[
              if (foods.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: foods.length,
                    itemBuilder: (context, foodIndex) {
                      final food = foods[foodIndex];
                      return ListTile(
                        leading: Image.network(
                          food.imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                        ),
                        title: Text(food.name),
                        subtitle: Text(
                          '${food.searchKcal}kcal | 単位: ${food.ccdsUnit}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              final kcal = _parseCalories(food.searchKcal);
                              currentCalories -= kcal;
                              if (currentCalories < 0) currentCalories = 0;
                              foods.removeAt(foodIndex);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              if (foods.isEmpty) const Spacer(),
              Container(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SearchScreen(mealType: cardTitle ?? '食事'),
                      ),
                    );

                    if (result != null && result is FoodItem) {
                      setState(() {
                        print(
                          'Adding food: ${result.name} with ${result.searchKcal}',
                        );

                        // Make sure the list exists
                        if (_selectedFoods[cardTitle] != null) {
                          _selectedFoods[cardTitle]!.add(result);

                          // Parse and add calories
                          final kcal = _parseCalories(result.searchKcal);
                          currentCalories += kcal;

                          print('Updated calories: $currentCalories');
                        }
                      });
                    }
                  },
                  child: const Icon(
                    Icons.add,
                    size: _iconSize,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  late final List<String?> _cardTitles;

  @override
  void initState() {
    super.initState();
    _cardTitles = [null, '朝食', '昼食', '夜食'];
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.only(top: 16.0),
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 200,
                width: 200,
                child: PieChart(
                  PieChartData(
                    sections: _getPieChartData(),
                    centerSpaceRadius: 60,
                    sectionsSpace: 0,
                  ),
                ),
              ),
              Text(
                '${currentCalories.toInt()} kcal',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._cardTitles.asMap().entries.map((e) => _buildCard(e.value, e.key)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomePage(),
      const Center(child: Text('履歴', style: TextStyle(fontSize: 24))),
      const Center(child: Text('設定', style: TextStyle(fontSize: 24))),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('NavigationBar サンプル')),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        destinations: _pages
            .map(
              (e) => NavigationDestination(icon: Icon(e.icon), label: e.title),
            )
            .toList(),
        onDestinationSelected: (index) async {
          await HapticFeedback.selectionClick();
          setState(() => _selectedIndex = index);
        },
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: _carbColor.withOpacity(0.2),
      ),
    );
  }
}
