import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'movie_details_page.dart';
import 'config.dart';

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
    await prefs.setStringList('favorites', favoriteMovies.map((id) => id.toString()).toList());
    return newFavoriteStatus;
  }

  Future<void> fetchMovies() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final response = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/discover/movie?api_key=${Config.apiKey}&sort_by=popularity.desc&page=$currentPage'));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
