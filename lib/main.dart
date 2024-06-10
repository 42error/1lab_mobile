import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() => runApp(NewsApp());

class NewsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Новостной клиент',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueGrey,
        hintColor: Colors.orangeAccent,
      ),
      home: NewsListScreen(),
    );
  }
}

class NewsListScreen extends StatefulWidget {
  @override
  _NewsListScreenState createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  List<dynamic> news = [];
  List<dynamic> filteredNews = [];
  bool isLoading = true;
  String apiKey = '1e8bc82bafd24756b05834ef6f959483';
  String selectedTag = 'Все';
  String errorMessage = '';
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> fetchNews() async {
    List<String> categories = [
      'business',
      'entertainment',
      'general',
      'health',
      'science',
      'sports',
      'technology'
    ];

    List<dynamic> allNews = [];

    for (String category in categories) {
      try {
        final response = await http.get(
          Uri.parse('https://newsapi.org/v2/top-headlines?country=us&category=$category&pageSize=30&apiKey=$apiKey'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          List<dynamic> articles = data['articles'] ?? [];
          for (var article in articles) {
            article['category'] = category;
          }
          allNews.addAll(articles);
        } else {
          throw Exception('Failed to load news');
        }
      } catch (e) {
        // Обработайте ошибку корректно
      }
    }

    if (allNews.isNotEmpty) {
      setState(() {
        news = allNews;
        applyFilters();
        isLoading = false;
      });
      saveNews(allNews);
    } else {
      final cachedNews = await loadNews();
      if (cachedNews.isNotEmpty) {
        setState(() {
          news = cachedNews;
          applyFilters();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Не удалось загрузить новости и нет кэшированных данных.';
          isLoading = false;
        });
      }
    }
  }

  Future<void> saveNews(List<dynamic> news) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('news', jsonEncode(news));
  }

  Future<List<dynamic>> loadNews() async {
    final prefs = await SharedPreferences.getInstance();
    final String? newsString = prefs.getString('news');
    if (newsString != null) {
      return List<dynamic>.from(json.decode(newsString));
    } else {
      return [];
    }
  }

  void filterNews(String tag) {
    setState(() {
      selectedTag = tag;
      applyFilters();
    });
  }

  void sortNewsByDate() {
    setState(() {
      filteredNews.sort((a, b) => DateTime.parse(b['publishedAt'] ?? DateTime.now().toString())
          .compareTo(DateTime.parse(a['publishedAt'] ?? DateTime.now().toString())));
    });
  }

  void applyFilters() {
    List<dynamic> tempFilteredNews = news;

    if (selectedTag != 'Все') {
      tempFilteredNews = tempFilteredNews.where((newsItem) => newsItem['category'] == selectedTag).toList();
    }

    if (selectedDate != null) {
      tempFilteredNews = tempFilteredNews.where((newsItem) {
        DateTime newsDate = DateTime.parse(newsItem['publishedAt']);
        return newsDate.year == selectedDate!.year &&
            newsDate.month == selectedDate!.month &&
            newsDate.day == selectedDate!.day;
      }).toList();
    }

    setState(() {
      filteredNews = tempFilteredNews;
    });
  }

  void _selectDate(BuildContext context) async {
    final DateTime firstDate = DateTime(2024, 6, 7); // Установка даты начала с 8 июня 2023 года
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (selectedDate != null && picked == selectedDate) {
          selectedDate = null; // Сбросить фильтр по дате при повторном выборе той же даты
        } else {
          selectedDate = picked;
        }
        applyFilters(); // Применить фильтры после выбора даты или её сброса
      });
    }
  }

  void _resetDateFilter() {
    setState(() {
      selectedDate = null;
      applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Новости'),
        actions: [
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: sortNewsByDate,
          ),
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          if (selectedDate != null)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _resetDateFilter,
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(child: Text(errorMessage))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              hint: Text('Выберите тег'),
              value: selectedTag,
              items: <String>[
                'Все',
                'business',
                'entertainment',
                'general',
                'health',
                'science',
                'sports',
                'technology'
              ].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) filterNews(value);
              },
            ),
          ),
          if (selectedDate != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Фильтр по дате: ${DateFormat.yMMMd().format(selectedDate!)}',
                    style: TextStyle(fontSize: 16),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: _resetDateFilter,
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredNews.length,
              itemBuilder: (context, index) {
                final newsItem = filteredNews[index];
                return Card(
                  child: ListTile(
                    leading: newsItem['urlToImage'] != null
                        ? Image.network(newsItem['urlToImage'], width: 100, height: 100, fit: BoxFit.cover)
                        : null,
                    title: Text(newsItem['title'] ?? 'No title'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat.yMMMd().format(DateTime.parse(newsItem['publishedAt'] ?? ''))),
                        Text(newsItem['category'] ?? 'No category'),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewsDetailScreen(newsItem: newsItem),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> newsItem;

  NewsDetailScreen({required this.newsItem});

  @override
  Widget build(BuildContext context) {
    saveOpenedNews(newsItem);
    return Scaffold(
      appBar: AppBar(
        title: Text('Новость'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              newsItem['urlToImage'] != null
                  ? Image.network(newsItem['urlToImage'])
                  : SizedBox.shrink(),
              SizedBox(height: 10),
              Text(newsItem['title'] ?? 'No title', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text(DateFormat.yMMMd().format(DateTime.parse(newsItem['publishedAt'] ?? ''))),
              SizedBox(height: 20),
              Text(
                newsItem['content']?.replaceAll(RegExp(r'\[.*?\]'), '') ??
                    newsItem['description'] ??
                    'Нет подробного описания',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void saveOpenedNews(Map<String, dynamic> newsItem) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> openedNews = prefs.getStringList('openedNews') ?? [];
    openedNews.add(jsonEncode(newsItem));
    prefs.setStringList('openedNews', openedNews);
  }
}