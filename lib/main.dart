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
  final String? cardTitle;
  final Widget? cardExtraContent;

  const PageData({
    required this.icon,
    required this.title,
    this.cardTitle,
    this.cardExtraContent,
  });
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
      final url = Uri.parse('https://calorie.slism.jp/?searchWord=$query&search=検索');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final searchNo = document.querySelectorAll('input.searchNo');
        final searchNameVal = document.querySelectorAll('input.searchNameVal');
        final ccdsUnit = document.querySelectorAll('span.ccds_unit');
        final searchKcal = document.querySelectorAll('span.searchKcal');

        final results = <FoodItem>[];
        final minLength = [searchNo.length, searchNameVal.length, ccdsUnit.length, searchKcal.length].reduce((a, b) => a < b ? a : b);

        for (var i = 0; i < minLength; i++) {
          final noValue = searchNo[i].attributes['value'] ?? '';
          final name = searchNameVal[i].attributes['value'] ?? '';
          final unit = ccdsUnit[i].text ?? 'N/A';
          final kcal = searchKcal[i].text ?? 'N/A';

          if (noValue.isNotEmpty && name.isNotEmpty) {
            results.add(FoodItem(
              // インデックスを追加する
              name: name,
              imageUrl: 'https://cdn.slism.jp/calorie/foodImages/$noValue.jpg',
              ccdsUnit: unit,
              searchKcal: kcal,
            ));
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
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Expanded(
            child: _searchResults.isEmpty && _errorMessage == null
            ? const Center(child: Text('検索結果がありません'))
            : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final food = _searchResults[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
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
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.add_circle, size: 30),
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
                );
              },
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

  Widget _buildBarChart(double current, double max, Color color, {double height = 70, double width = 25}) {
    final percentage = current / max;
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PageData data, int index) => Card(
        shape: const RoundedRectangleBorder(borderRadius: _cardBorderRadius),
        child: SizedBox(
          width: double.infinity,
          height: index == 0 ? _macroCardHeight : _cardHeight,
          child: Stack(
            children: [
              if (data.cardTitle != null)
                Positioned(
                  top: _cardMargin,
                  left: _cardMargin,
                  child: Text(
                    data.cardTitle!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              Positioned(
                left: _cardMargin,
                right: _cardMargin,
                bottom: _cardMargin,
                child: data.cardExtraContent ??
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SearchScreen(mealType: data.cardTitle ?? '食事')),
                      ),
                      child: const Icon(Icons.add, size: _iconSize, color: Colors.blue),
                    ),
              ),
            ],
          ),
        ),
      );

  late final List<PageData> _cardData;
  late final List<Widget> _pageWidgets;

  @override
  void initState() {
    super.initState();
    _cardData = [
      PageData(
        icon: Icons.square_rounded,
        title: '',
        cardExtraContent: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${currentCalories.toInt()}', style: const TextStyle(fontSize: 30)),
                        Text(' /${maxCalories.toInt()}kcal', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                    Text('残り${(maxCalories - currentCalories).toInt()}kcal', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
                Row(
                  children: [
                    _buildBarChart(proteinCurrent, proteinMax, _proteinColor),
                    const SizedBox(width: 3),
                    _buildBarChart(carbCurrent, carbMax, _carbColor),
                    const SizedBox(width: 3),
                    _buildBarChart(fatCurrent, fatMax, _fatColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMacroRow('タンパク質', proteinCurrent, proteinMax, _proteinColor),
            const SizedBox(height: 8),
            _buildMacroRow('炭水化物', carbCurrent, carbMax, _carbColor),
            const SizedBox(height: 8),
            _buildMacroRow('脂質', fatCurrent, fatMax, _fatColor),
          ],
        ),
      ),
      const PageData(icon: Icons.add_box_rounded, title: '', cardTitle: '朝食'),
      const PageData(icon: Icons.add_box_rounded, title: '', cardTitle: '昼食'),
      const PageData(icon: Icons.add_box_rounded, title: '', cardTitle: '夜食'),
    ];

    _pageWidgets = [
      ListView(
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
                Text('${currentCalories.toInt()} kcal', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._cardData.asMap().entries.map((e) => _buildCard(e.value, e.key)),
        ],
      ),
      const Center(child: Text('履歴', style: TextStyle(fontSize: 24))),
      const Center(child: Text('設定', style: TextStyle(fontSize: 24))),
    ];
  }

  Widget _buildMacroRow(String label, double current, double max, Color color) => Row(
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
              Text('${current.toInt()}', style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold)),
              Text('/${max.toInt()}g', style: const TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('NavigationBar サンプル')),
        body: _pageWidgets[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          destinations: _pages.map((e) => NavigationDestination(icon: Icon(e.icon), label: e.title)).toList(),
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