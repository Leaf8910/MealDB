// services/meal_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class MealApiService {
  static const String baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  // Search meals by name
  Future<List<Recipe>> searchMeals(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/search.php?s=$query'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data['meals'] == null) {
        return [];
      }
      
      return List<Recipe>.from(data['meals'].map((meal) => Recipe.fromJson(meal)));
    } else {
      throw Exception('Failed to search meals');
    }
  }

  // Get random meal
  Future<Recipe> getRandomMeal() async {
    final response = await http.get(Uri.parse('$baseUrl/random.php'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Recipe.fromJson(data['meals'][0]);
    } else {
      throw Exception('Failed to get random meal');
    }
  }

  // Get meal categories
  Future<List<String>> getCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/categories.php'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return List<String>.from(data['categories'].map((category) => category['strCategory']));
    } else {
      throw Exception('Failed to get categories');
    }
  }

  // Get meals by category
  Future<List<Recipe>> getMealsByCategory(String category) async {
    final response = await http.get(Uri.parse('$baseUrl/filter.php?c=$category'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      // The filter endpoint only returns partial meal info
      // We need to get full details for each meal
      List<Recipe> recipes = [];
      for (var meal in data['meals']) {
        final detailResponse = await http.get(
          Uri.parse('$baseUrl/lookup.php?i=${meal['idMeal']}')
        );
        
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(detailResponse.body);
          recipes.add(Recipe.fromJson(detailData['meals'][0]));
        }
      }
      
      return recipes;
    } else {
      throw Exception('Failed to get meals by category');
    }
  }
}