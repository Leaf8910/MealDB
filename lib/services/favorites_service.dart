import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

class FavoritesService {
  static const String favoritesKey = 'favorite_recipes';
  
  //favorite recipes
  Future<List<Recipe>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesData = prefs.getStringList(favoritesKey) ?? [];
    
    final List<Recipe> favorites = [];
    for (final recipeJson in favoritesData) {
      try {
        final recipeMap = json.decode(recipeJson);
        favorites.add(Recipe.fromJson(recipeMap));
      } catch (e) {

      }
    }
    
    return favorites;
  }
  
  //recipe is favorited
  Future<bool> isFavorite(String recipeId) async {
    final favorites = await getFavorites();
    return favorites.any((recipe) => recipe.id == recipeId);
  }
  
  //to favorites
  Future<void> addFavorite(Recipe recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesData = prefs.getStringList(favoritesKey) ?? [];
    
    //already in favorites
    if (await isFavorite(recipe.id)) {
      return;
    }
    

    favoritesData.add(json.encode(recipe.toJson()));
    await prefs.setStringList(favoritesKey, favoritesData);
  }
  
  // Remove recipe from favorites
  Future<void> removeFavorite(String recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesData = prefs.getStringList(favoritesKey) ?? [];
    
    //remove the recipe
    final List<String> updatedFavorites = [];
    for (final recipeJson in favoritesData) {
      try {
        final recipeMap = json.decode(recipeJson);
        final recipe = Recipe.fromJson(recipeMap);
        if (recipe.id != recipeId) {
          updatedFavorites.add(recipeJson);
        }
      } catch (e) {

        updatedFavorites.add(recipeJson);
      }
    }
    
    await prefs.setStringList(favoritesKey, updatedFavorites);
  }
  
  Future<bool> toggleFavorite(Recipe recipe) async {
    final isFav = await isFavorite(recipe.id);
    
    if (isFav) {
      await removeFavorite(recipe.id);
      return false;
    } else {
      await addFavorite(recipe);
      return true;
    }
  }
}