import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'movie_details_page.dart';
import 'config.dart';
import 'package:flutter/cupertino.dart';
import 'favorites_page.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMDB Popular Movies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    MovieListPage(initialTitle: 'Popular Movies'),
    FavoritesPage(),
    Text('Profile'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.movie),
            label: 'Movies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key, required this.initialTitle});

  final String initialTitle;

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  late String _title;
  List<dynamic> movies = [];
  Set<int> favoriteMovies = {};
  int currentPage = 1;
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();
  String currentCategory = 'popular';
  String currentSortOption = 'popularity.desc';
  String? selectedYear;
  RangeValues _ratingRange = const RangeValues(0, 10);
  List<String> _selectedGenres = [];
  bool _filtersActive = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  String _searchQuery = '';

  final Map<String, int> _genreMap = {
    "Action": 28,
    "Adventure": 12,
    "Animation": 16,
    "Comedy": 35,
    "Crime": 80,
    "Drama": 18,
    "Fantasy": 14,
    "Horror": 27,
    "Romance": 10749,
    "Science Fiction": 878,
  };

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    fetchMovies();
    _scrollController.addListener(_scrollListener);
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      fetchMovies();
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    setState(() {
      favoriteMovies = favorites.map((id) => int.parse(id)).toSet();
    });
  }

  Future<bool> _toggleFavorite(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final newFavoriteStatus = !favoriteMovies.contains(movieId);
    setState(() {
      if (newFavoriteStatus) {
        favoriteMovies.add(movieId);
      } else {
        favoriteMovies.remove(movieId);
      }
    });
    await prefs.setStringList(
        'favorites', favoriteMovies.map((id) => id.toString()).toList());
    return newFavoriteStatus;
  }

  Future<void> fetchMovies() async {
    if (isLoading || _isSearching) return;

    setState(() {
      isLoading = true;
    });

    String endpoint;
    final Map<String, dynamic> queryParams = {
      'api_key': Config.apiKey,
      'page': currentPage.toString(),
    };

    // Always use discover endpoint to apply filters consistently
    endpoint = '/3/discover/movie';

    // Add filters for all categories
    queryParams.addAll({
      'sort_by': getSortByParam(),
      'with_genres': _selectedGenres.isNotEmpty ? await _getGenreIds(_selectedGenres).then((ids) => ids.join(',')) : null,
      'primary_release_year': selectedYear,
      'vote_average.gte': _ratingRange.start.toString(),
      'vote_average.lte': _ratingRange.end.toString(),
    });

    // Add category-specific parameters
    switch (currentCategory) {
      case 'upcoming':
        queryParams['primary_release_date.gte'] = DateTime.now().toString().substring(0, 10);
        break;
      case 'now_playing':
        queryParams['primary_release_date.lte'] = DateTime.now().toString().substring(0, 10);
        break;
    }

    // Remove null values from queryParams
    queryParams.removeWhere((key, value) => value == null);

    final Uri url = Uri.https('api.themoviedb.org', endpoint, queryParams);

    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        movies.addAll(json.decode(response.body)['results']);
        currentPage++;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load movies');
    }
  }

  String getSortByParam() {
    switch (currentCategory) {
      case 'popular':
        return 'popularity.desc';
      case 'top_rated':
        return 'vote_average.desc';
      case 'upcoming':
        return 'primary_release_date.asc';
      case 'now_playing':
        return 'primary_release_date.desc';
      default:
        return currentSortOption;
    }
  }

  Future<List<int>> _getGenreIds(List<String> genreNames) async {
    return genreNames.map((name) => _genreMap[name] ?? 0).where((id) => id != 0).toList();
  }

  void changeCategory(String category) {
    setState(() {
      currentCategory = category;
      movies.clear();
      currentPage = 1;
      // Update the title based on the selected category
      switch (category) {
        case 'popular':
          _title = 'Popular Movies';
          break;
        case 'top_rated':
          _title = 'Top Rated Movies';
          break;
        case 'upcoming':
          _title = 'Upcoming Movies';
          break;
        case 'now_playing':
          _title = 'Now Playing Movies';
          break;
      }
    });
    fetchMovies();
  }

  void changeSortOption(String sortOption) {
    setState(() {
      currentSortOption = sortOption;
      movies.clear();
      currentPage = 1;
    });
    fetchMovies();
  }

  void changeYear(String? year) {
    setState(() {
      selectedYear = year;
      movies.clear();
      currentPage = 1;
    });
    fetchMovies();
  }

  void _showFilterBottomSheet() {
    TextEditingController customYearController = TextEditingController(text: selectedYear);
    FocusNode yearFocusNode = FocusNode();

    void _submitYear() {
      if (customYearController.text.isNotEmpty) {
        selectedYear = customYearController.text;
      } else {
        selectedYear = null;
      }
      yearFocusNode.unfocus();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 5,
                      width: 40,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filters',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Genres',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                children: _genreMap.keys.map((String genre) {
                                  return FilterChip(
                                    label: Text(genre),
                                    selected: _selectedGenres.contains(genre),
                                    onSelected: (bool selected) {
                                      setModalState(() {
                                        if (selected) {
                                          _selectedGenres.add(genre);
                                        } else {
                                          _selectedGenres.remove(genre);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Release Year',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: customYearController,
                                      focusNode: yearFocusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Enter custom year',
                                        border: OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(Icons.check),
                                          onPressed: _submitYear,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (value) {
                                        setModalState(() {
                                          selectedYear = value.isNotEmpty ? value : null;
                                        });
                                      },
                                      onSubmitted: (_) {
                                        _submitYear();
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () {
                                      setModalState(() {
                                        selectedYear = null;
                                        customYearController.clear();
                                        yearFocusNode.unfocus();
                                      });
                                    },
                                    child: Text('Clear'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                children: List.generate(10, (index) {
                                  final year = DateTime.now().year - index;
                                  return ChoiceChip(
                                    label: Text(year.toString()),
                                    selected: selectedYear == year.toString(),
                                    onSelected: (bool selected) {
                                      setModalState(() {
                                        if (selected) {
                                          selectedYear = year.toString();
                                          customYearController.text = year.toString();
                                        } else {
                                          selectedYear = null;
                                          customYearController.clear();
                                        }
                                      });
                                    },
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Rating Range',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              RangeSlider(
                                values: _ratingRange,
                                min: 0,
                                max: 10,
                                divisions: 20,
                                labels: RangeLabels(
                                  _ratingRange.start.toStringAsFixed(1),
                                  _ratingRange.end.toStringAsFixed(1),
                                ),
                                onChanged: (RangeValues values) {
                                  setModalState(() {
                                    _ratingRange = values;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () {
                          // Apply filters and fetch movies
                          Navigator.pop(context);
                          setState(() {
                            movies.clear();
                            currentPage = 1;
                            _filtersActive = selectedYear != null || 
                                             _ratingRange != const RangeValues(0, 10) || 
                                             _selectedGenres.isNotEmpty;
                          });
                          fetchMovies();
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _searchQuery = query;
          movies.clear();
          currentPage = 1;
        });
        _searchMovies(query);
      } else {
        setState(() {
          _isSearching = false;
          _searchQuery = '';
          movies.clear();
          currentPage = 1;
        });
        fetchMovies();
      }
    });
  }

  Future<void> _searchMovies(String query) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final response = await http.get(
      Uri.https('api.themoviedb.org', '/3/search/movie', {
        'api_key': Config.apiKey,
        'query': query,
        'page': currentPage.toString(),
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        movies.addAll(json.decode(response.body)['results']);
        currentPage++;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to search movies');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          PopupMenuButton<String>(
            onSelected: changeCategory,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'popular',
                child: Text('Popular'),
              ),
              const PopupMenuItem<String>(
                value: 'top_rated',
                child: Text('Top Rated'),
              ),
              const PopupMenuItem<String>(
                value: 'upcoming',
                child: Text('Upcoming'),
              ),
              const PopupMenuItem<String>(
                value: 'now_playing',
                child: Text('Now Playing'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search movies...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: movies.length + 1,
              itemBuilder: (context, index) {
                if (index < movies.length) {
                  final movie = movies[index];
                  final isFavorite = favoriteMovies.contains(movie['id']);
                  return ListTile(
                    leading: movie['poster_path'] != null
                      ? SizedBox(
                          width: 50,
                          height: 75,
                          child: Image.network(
                            'https://image.tmdb.org/t/p/w92${movie['poster_path']}',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.error, size: 50);
                            },
                          ),
                        )
                      : const Icon(Icons.movie, size: 50),
                    title: Text(movie['title']),
                    subtitle: Text(movie['release_date'] ?? 'Release date unknown'),
                    trailing: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                      ),
                      onPressed: () => _toggleFavorite(movie['id']),
                    ),
                    onTap: () async {
                      final newFavoriteStatus = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MovieDetailsPage(
                            movie: movie,
                            initialIsFavorite: isFavorite,
                            onFavoriteToggle: () async {
                              final newStatus = await _toggleFavorite(movie['id']);
                              return newStatus;
                            },
                          ),
                        ),
                      );
                      if (newFavoriteStatus != null) {
                        setState(() {
                          if (newFavoriteStatus) {
                            favoriteMovies.add(movie['id']);
                          } else {
                            favoriteMovies.remove(movie['id']);
                          }
                        });
                      }
                    },
                  );
                } else if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
