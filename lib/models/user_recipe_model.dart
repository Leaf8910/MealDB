import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enhanced_recipe.dart';

class UserRecipeModel {
  final String? id; // Null when creating new, assigned by Firestore
  final String userId;
  final String name;
  final String category;
  final String area;
  final String instructions;
  final String? thumbnailUrl;
  final String? localImagePath; // Used temporarily when uploading
  final Map<String, String> ingredients;
  final String? youtubeUrl;
  final List<String> tags;
  final bool isPublic; 
  final DateTime createdAt;
  final DateTime updatedAt;

  UserRecipeModel({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.area,
    required this.instructions,
    this.thumbnailUrl,
    this.localImagePath,
    required this.ingredients,
    this.youtubeUrl,
    List<String>? tags,
    this.isPublic = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    tags = tags ?? [],
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'category': category,
      'area': area,
      'instructions': instructions,
      'thumbnailUrl': thumbnailUrl,
      'ingredients': ingredients,
      'youtubeUrl': youtubeUrl,
      'tags': tags,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserRecipeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserRecipeModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      area: data['area'] ?? '',
      instructions: data['instructions'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      ingredients: Map<String, String>.from(data['ingredients'] ?? {}),
      youtubeUrl: data['youtubeUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      isPublic: data['isPublic'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  EnhancedRecipe toEnhancedRecipe() {
    return EnhancedRecipe(
      id: id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: category,
      area: area,
      instructions: instructions,
      thumbnail: thumbnailUrl ?? '',
      ingredients: ingredients,
      youtubeUrl: youtubeUrl,
      source: 'User Recipe',
      tags: tags,
    );
  }

UserRecipeModel copyWith({
  String? id,
  String? name,
  String? category,
  String? area,
  String? instructions,
  String? thumbnailUrl,
  String? localImagePath,
  Map<String, String>? ingredients,
  String? youtubeUrl,
  List<String>? tags,
  bool? isPublic,
  DateTime? updatedAt,  // Make sure this parameter is included
}) {
  return UserRecipeModel(
    id: id ?? this.id,
    userId: this.userId,
    name: name ?? this.name,
    category: category ?? this.category,
    area: area ?? this.area,
    instructions: instructions ?? this.instructions,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    localImagePath: localImagePath ?? this.localImagePath,
    ingredients: ingredients ?? this.ingredients,
    youtubeUrl: youtubeUrl ?? this.youtubeUrl,
    tags: tags ?? this.tags,
    isPublic: isPublic ?? this.isPublic,
    createdAt: this.createdAt,
    updatedAt: updatedAt ?? DateTime.now(),  
  );
}
}