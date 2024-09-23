import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'movie_details_page.dart';
import 'config.dart';
import 'package:flutter/cupertino.dart';

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
      home: const MovieListPage(title: 'Popular Movies'),
    );
  }
}

class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key, required this.title});

  final String title;

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
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
    fetchMovies();
    _scrollController.addListener(_scrollListener);
    _loadFavorites();
  }

  @override
  void dispose() {
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
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    String url = 'https://api.themoviedb.org/3/discover/movie?api_key=${Config.apiKey}&sort_by=$currentSortOption&page=$currentPage';

    if (selectedYear != null) {
      url += '&primary_release_year=$selectedYear';
    }

    url += '&vote_average.gte=${_ratingRange.start}&vote_average.lte=${_ratingRange.end}';

    if (_selectedGenres.isNotEmpty) {
      final genreIds = await _getGenreIds(_selectedGenres);
      url += '&with_genres=${genreIds.join(',')}';
    }

    final response = await http.get(Uri.parse(url));

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

  Future<List<int>> _getGenreIds(List<String> genreNames) async {
    return genreNames.map((name) => _genreMap[name] ?? 0).where((id) => id != 0).toList();
  }

  void changeCategory(String category) {
    setState(() {
      currentCategory = category;
      selectedYear = null; // Reset year selection when changing categories
      movies.clear();
      currentPage = 1;
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
    String? customYear;
    TextEditingController customYearController = TextEditingController();
    FocusNode yearFocusNode = FocusNode();

    void _submitYear() {
      if (customYearController.text.isNotEmpty) {
        customYear = customYearController.text;
        selectedYear = customYear;
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
            return Container(
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
                    child: ListView(
                      padding: const EdgeInsets.all(16),
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
                                onChanged: (value) {
                                  setModalState(() {
                                    customYear = value.isNotEmpty ? value : null;
                                    selectedYear = customYear;
                                  });
                                },
                                onSubmitted: (_) => _submitYear(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  customYear = null;
                                  customYearController.clear();
                                  selectedYear = null;
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
                                  selectedYear = selected ? year.toString() : null;
                                  customYear = null;
                                  customYearController.clear();
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () {
                        // Apply filters and fetch movies
                        Navigator.pop(context);
                        setState(() {
                          movies.clear();
                          currentPage = 1;
                        });
                        fetchMovies();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: changeCategory,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'popular',
                child: Text('Popular'),
              ),
              const PopupMenuItem<String>(
                value: 'now_playing',
                child: Text('Now Playing'),
              ),
              const PopupMenuItem<String>(
                value: 'upcoming',
                child: Text('Upcoming'),
              ),
              const PopupMenuItem<String>(
                value: 'top_rated',
                child: Text('Top Rated'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: changeYear,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: null,
                child: Text('All Years'),
              ),
              ...List.generate(10, (index) {
                final year = DateTime.now().year - index;
                return PopupMenuItem<String>(
                  value: year.toString(),
                  child: Text(year.toString()),
                );
              }),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 4),
                  Text(selectedYear ?? 'All Years'),
                ],
              ),
            ),
          ),
          if (currentCategory == 'discover')
            PopupMenuButton<String>(
              onSelected: changeSortOption,
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'popularity.desc',
                  child: Text('Popularity Descending'),
                ),
                const PopupMenuItem<String>(
                  value: 'popularity.asc',
                  child: Text('Popularity Ascending'),
                ),
                const PopupMenuItem<String>(
                  value: 'vote_average.desc',
                  child: Text('Rating Descending'),
                ),
                const PopupMenuItem<String>(
                  value: 'vote_average.asc',
                  child: Text('Rating Ascending'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: movies.length + 1,
        itemBuilder: (context, index) {
          if (index < movies.length) {
            final movie = movies[index];
            final isFavorite = favoriteMovies.contains(movie['id']);
            return ListTile(
              leading: Image.network(
                'https://image.tmdb.org/t/p/w92${movie['poster_path']}',
                width: 50,
                height: 75,
                fit: BoxFit.cover,
              ),
              title: Text(movie['title']),
              subtitle: Text(movie['release_date']),
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
    );
  }
}
