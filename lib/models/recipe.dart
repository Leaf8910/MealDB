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
    final Map<String, String> ingredients = {};
    
    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];
      
      if (ingredient != null && ingredient.toString().trim().isNotEmpty &&
          measure != null && measure.toString().trim().isNotEmpty) {
        ingredients[ingredient] = measure;
      }
    }
    
    return Recipe(
      id: json['idMeal'],
      name: json['strMeal'],
      category: json['strCategory'] ?? 'Unknown',
      area: json['strArea'] ?? 'Unknown',
      instructions: json['strInstructions'] ?? '',
      thumbnail: json['strMealThumb'] ?? '',
      ingredients: ingredients,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'idMeal': id,
      'strMeal': name,
      'strCategory': category,
      'strArea': area,
      'strInstructions': instructions,
      'strMealThumb': thumbnail,
    };
    
    int i = 1;
    for (final entry in ingredients.entries) {
      json['strIngredient$i'] = entry.key;
      json['strMeasure$i'] = entry.value;
      i++;
    }
    
    return json;
  }
}