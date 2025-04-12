// models/recipe.dart
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
    // Create a map for ingredients and measurements
    Map<String, String> ingredientsMap = {};
    
    // TheMealDB API provides ingredients as ingredient1, ingredient2, etc.
    // and measurements as measure1, measure2, etc.
    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];
      
      // Only add if ingredient is not empty
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
}