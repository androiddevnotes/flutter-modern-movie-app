import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'movie_details_page.dart';
import 'config.dart';
import 'widgets/movie_list_item.dart';
import 'dart:async';
import 'globals.dart';

// Remove the favoritesStreamController from this file as it's now in globals.dart

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with AutomaticKeepAliveClientMixin {
  List<dynamic> favoriteMovies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteMovies();
    favoritesStreamController.stream.listen((_) {
      _loadFavoriteMovies();
    });
  }

  Future<void> _loadFavoriteMovies() async {
    setState(() {
      isLoading = true;
    });

    List<dynamic> movies = [];
    for (int id in globalFavorites) {
      print('Fetching details for movie ID: $id'); // Debug print
      final movie = await _fetchMovieDetails(id);
      if (movie != null) {
        movies.add(movie);
        print('Added movie to favorites: ${movie['title']}'); // Debug print
      } else {
        print('Failed to fetch details for movie ID: $id'); // Debug print
      }
    }

    setState(() {
      favoriteMovies = movies;
      isLoading = false;
    });
    print('Total favorite movies loaded: ${favoriteMovies.length}'); // Debug print
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
    globalFavorites.remove(movieId);
    await prefs.setStringList('favorites', globalFavorites.map((id) => id.toString()).toList());

    setState(() {
      favoriteMovies.removeWhere((movie) => movie['id'] == movieId);
    });

    updateGlobalFavorites(globalFavorites);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);  // This is important for AutomaticKeepAliveClientMixin
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
        return MovieListItem(
          movie: movie,
          isFavorite: true,
          onTap: () async {
            final newFavoriteStatus = await Navigator.push<bool>(
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
            if (newFavoriteStatus == false) {
              setState(() {
                favoriteMovies.removeWhere((m) => m['id'] == movie['id']);
              });
            }
          },
          onFavoriteToggle: () async {
            await _removeFromFavorites(movie['id']);
            setState(() {
              favoriteMovies.removeWhere((m) => m['id'] == movie['id']);
            });
          },
        );
      },
    );
  }
}