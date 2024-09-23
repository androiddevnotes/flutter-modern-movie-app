import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'movie_details_page.dart';
import 'config.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<dynamic> favoriteMovies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteMovies();
  }

  Future<void> _loadFavoriteMovies() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    
    List<dynamic> movies = [];
    for (String id in favorites) {
      final movie = await _fetchMovieDetails(int.parse(id));
      if (movie != null) {
        movies.add(movie);
      }
    }

    setState(() {
      favoriteMovies = movies;
      isLoading = false;
    });
  }

  Future<Map<String, dynamic>?> _fetchMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.https('api.themoviedb.org', '/3/movie/$movieId', {
        'api_key': Config.apiKey,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('Failed to load movie details for ID: $movieId');
      return null;
    }
  }

  Future<void> _removeFromFavorites(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    favorites.remove(movieId.toString());
    await prefs.setStringList('favorites', favorites);

    setState(() {
      favoriteMovies.removeWhere((movie) => movie['id'] == movieId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (favoriteMovies.isEmpty) {
      return const Center(child: Text('No favorite movies yet.'));
    }

    return ListView.builder(
      itemCount: favoriteMovies.length,
      itemBuilder: (context, index) {
        final movie = favoriteMovies[index];
        return ListTile(
          leading: movie['poster_path'] != null
            ? Image.network(
                'https://image.tmdb.org/t/p/w92${movie['poster_path']}',
                width: 50,
                height: 75,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 50);
                },
              )
            : const Icon(Icons.movie, size: 50),
          title: Text(movie['title']),
          subtitle: Text(movie['release_date'] ?? 'Release date unknown'),
          trailing: IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red),
            onPressed: () => _removeFromFavorites(movie['id']),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailsPage(
                  movie: movie,
                  initialIsFavorite: true,
                  onFavoriteToggle: () async {
                    await _removeFromFavorites(movie['id']);
                    return false;
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}