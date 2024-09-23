import 'dart:async';

Set<int> globalFavorites = {};
final favoritesStreamController = StreamController<void>.broadcast();

void updateGlobalFavorites(Set<int> newFavorites) {
  globalFavorites = newFavorites;
  favoritesStreamController.add(null);
}