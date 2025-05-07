// lib/models/enhanced_recipe.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancedRecipe {
  final String id;
  final String name;
  final String category;
  final String area;
  final String instructions;
  final String thumbnail;
  final Map<String, String> ingredients;
  final String? youtubeUrl;
  final String? source;
  final List<String> tags;
  final double averageRating;
  final int ratingCount;
  
  final int favoriteCount;
  final int commentCount;

  EnhancedRecipe({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.instructions,
    required this.thumbnail,
    required this.ingredients,
    this.youtubeUrl,
    this.source,
    List<String>? tags,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.favoriteCount = 0,
    this.commentCount = 0,
  }) : tags = tags ?? [];

  factory EnhancedRecipe.fromJson(Map<String, dynamic> json) {
    Map<String, String> ingredientsMap = {};
    
    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];
      
      if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
        ingredientsMap[ingredient] = measure ?? '';
      }
    }

    List<String> tagsList = [];
    if (json['strTags'] != null && json['strTags'].toString().isNotEmpty) {
      tagsList = json['strTags'].toString().split(',');
    }

    return EnhancedRecipe(
      id: json['idMeal'] ?? '',
      name: json['strMeal'] ?? '',
      category: json['strCategory'] ?? '',
      area: json['strArea'] ?? '',
      instructions: json['strInstructions'] ?? '',
      thumbnail: json['strMealThumb'] ?? '',
      ingredients: ingredientsMap,
      youtubeUrl: json['strYoutube'],
      source: json['strSource'],
      tags: tagsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'area': area,
      'instructions': instructions,
      'thumbnail': thumbnail,
      'ingredients': ingredients,
      'youtubeUrl': youtubeUrl,
      'source': source,
      'tags': tags,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'favoriteCount': favoriteCount,
      'commentCount': commentCount,
    };
  }


  factory EnhancedRecipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return EnhancedRecipe(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      area: data['area'] ?? '',
      instructions: data['instructions'] ?? '',
      thumbnail: data['thumbnail'] ?? '',
      ingredients: Map<String, String>.from(data['ingredients'] ?? {}),
      youtubeUrl: data['youtubeUrl'],
      source: data['source'],
      tags: List<String>.from(data['tags'] ?? []),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      favoriteCount: data['favoriteCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }

  factory EnhancedRecipe.fromRecipe(Recipe recipe, {
    String? youtubeUrl,
    String? source,
    List<String>? tags,
  }) {
    return EnhancedRecipe(
      id: recipe.id,
      name: recipe.name,
      category: recipe.category,
      area: recipe.area,
      instructions: recipe.instructions,
      thumbnail: recipe.thumbnail,
      ingredients: recipe.ingredients,
      youtubeUrl: youtubeUrl,
      source: source,
      tags: tags,
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final String category;
  final String area;
  final String instructions;
  final String thumbnail;
  final Map<String, String> ingredients;

  Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.instructions,
    required this.thumbnail,
    required this.ingredients,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    Map<String, String> ingredientsMap = {};
    
    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];
      

      if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
        ingredientsMap[ingredient] = measure ?? '';
      }
    }

    return Recipe(
      id: json['idMeal'] ?? '',
      name: json['strMeal'] ?? '',
      category: json['strCategory'] ?? '',
      area: json['strArea'] ?? '',
      instructions: json['strInstructions'] ?? '',
      thumbnail: json['strMealThumb'] ?? '',
      ingredients: ingredientsMap,
    );
  }

  // Convert to EnhancedRecipe
  EnhancedRecipe toEnhanced({
    String? youtubeUrl,
    String? source,
    List<String>? tags,
  }) {
    return EnhancedRecipe.fromRecipe(
      this,
      youtubeUrl: youtubeUrl,
      source: source,
      tags: tags,
    );
  }
}