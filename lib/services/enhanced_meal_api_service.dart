import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/enhanced_recipe.dart';

class EnhancedMealApiService {
  static const String baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  // Search meals
  Future<List<EnhancedRecipe>> searchMeals(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/search.php?s=$query'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data['meals'] == null) {
        return [];
      }
      
      return List<EnhancedRecipe>.from(
        data['meals'].map((meal) => EnhancedRecipe.fromJson(meal))
      );
    } else {
      throw Exception('Failed to search meals');
    }
  }

  //meal by ID
  Future<EnhancedRecipe?> getMealById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/lookup.php?i=$id'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data['meals'] == null || data['meals'].isEmpty) {
        return null;
      }
      
      return EnhancedRecipe.fromJson(data['meals'][0]);
    } else {
      throw Exception('Failed to get meal by ID');
    }
  }

  //random meal
  Future<EnhancedRecipe> getRandomMeal() async {
    final response = await http.get(Uri.parse('$baseUrl/random.php'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return EnhancedRecipe.fromJson(data['meals'][0]);
    } else {
      throw Exception('Failed to get random meal');
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
  final response = await http.get(Uri.parse('$baseUrl/categories.php'));
  
  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);
    return List<Map<String, dynamic>>.from(
      data['categories'].map((category) => {
        'id': category['idCategory'] ?? '',
        'name': category['strCategory'] ?? '',
        'thumbnail': category['strCategoryThumb'] ?? '',
        'description': category['strCategoryDescription'] ?? '',
      })
    );
  } else {
    throw Exception('Failed to get categories');
  }
}
  //area/cuisine list
  Future<List<String>> getAreas() async {
    final response = await http.get(Uri.parse('$baseUrl/list.php?a=list'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return List<String>.from(
        data['meals'].map((area) => area['strArea'])
      );
    } else {
      throw Exception('Failed to get areas');
    }
  }

  //meals by category
  Future<List<EnhancedRecipe>> getMealsByCategory(String category) async {
    final response = await http.get(Uri.parse('$baseUrl/filter.php?c=$category'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data['meals'] == null) {
        return [];
      }
      
      //filter endpoint only returns partial meal info
      List<EnhancedRecipe> recipes = [];
      for (var meal in data['meals']) {
        try {
          // Get full details for each meal
          final detailResponse = await http.get(
            Uri.parse('$baseUrl/lookup.php?i=${meal['idMeal']}')
          );
          
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            if (detailData['meals'] != null && detailData['meals'].isNotEmpty) {
              recipes.add(EnhancedRecipe.fromJson(detailData['meals'][0]));
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      return recipes;
    } else {
      throw Exception('Failed to get meals by category');
    }
  }

  Future<List<EnhancedRecipe>> getMealsByArea(String area) async {
    final response = await http.get(Uri.parse('$baseUrl/filter.php?a=$area'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data['meals'] == null) {
        return [];
      }

      List<EnhancedRecipe> recipes = [];
      for (var meal in data['meals']) {
        try {
          // Get full details for each meal
          final detailResponse = await http.get(
            Uri.parse('$baseUrl/lookup.php?i=${meal['idMeal']}')
          );
          
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            if (detailData['meals'] != null && detailData['meals'].isNotEmpty) {
              recipes.add(EnhancedRecipe.fromJson(detailData['meals'][0]));
            }
          }
        } catch (e) {

          continue;
        }
      }
      
      return recipes;
    } else {
      throw Exception('Failed to get meals by area');
    }
  }


  Future<List<EnhancedRecipe>> filterMeals({
    String? category,
    String? area,
    String? ingredient,
  }) async {
    String endpoint = '$baseUrl/filter.php?';
    
    if (category != null) {
      endpoint += 'c=$category';
    } else if (area != null) {
      endpoint += 'a=$area';
    } else if (ingredient != null) {
      endpoint += 'i=$ingredient';
    } else {
      // Return empty list if no filter criteria provided
      return [];
    }
    
    final response = await http.get(Uri.parse(endpoint));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data['meals'] == null) {
        return [];
      }
      

      List<EnhancedRecipe> recipes = [];
      
      // Limit to first 10 results
      final mealList = (data['meals'] as List).take(10).toList();
      
      for (var meal in mealList) {
        try {
          final detailResponse = await http.get(
            Uri.parse('$baseUrl/lookup.php?i=${meal['idMeal']}')
          );
          
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            if (detailData['meals'] != null && detailData['meals'].isNotEmpty) {
              recipes.add(EnhancedRecipe.fromJson(detailData['meals'][0]));
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      return recipes;
    } else {
      throw Exception('Failed to filter meals');
    }
  }

  Future<List<EnhancedRecipe>> getMultipleRandomMeals(int count) async {
    List<EnhancedRecipe> recipes = [];
    
    for (int i = 0; i < count; i++) {
      try {
        final recipe = await getRandomMeal();
        if (!recipes.any((r) => r.id == recipe.id)) {
          recipes.add(recipe);
        }
      } catch (e) {
        continue;
      }
    }
    
    return recipes;
  }


  Future<List<String>> getIngredients() async {
    final response = await http.get(Uri.parse('$baseUrl/list.php?i=list'));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return List<String>.from(
        data['meals'].map((ingredient) => ingredient['strIngredient'])
      );
    } else {
      throw Exception('Failed to get ingredients');
    }
  }
}