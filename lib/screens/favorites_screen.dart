// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enhanced_recipe.dart';
import '../services/auth_service.dart';
import '../services/user_interaction_service.dart';
import '../services/enhanced_meal_api_service.dart';
import 'widgets/app_drawer.dart';
import 'recipe_detail_screen.dart';
import 'auth/login_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final UserInteractionService _userInteractionService = UserInteractionService();
  final EnhancedMealApiService _apiService = EnhancedMealApiService();
  
  List<EnhancedRecipe> _favoriteRecipes = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }
  
  Future<void> _loadFavorites() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get favorite recipe IDs
      final favoriteIds = await _userInteractionService.getFavoriteIds();
      
      if (favoriteIds.isEmpty) {
        setState(() {
          _favoriteRecipes = [];
          _isLoading = false;
        });
        return;
      }
      
      // Load recipe details for each ID
      List<EnhancedRecipe> recipes = [];
      for (final id in favoriteIds) {
        try {
          final recipe = await _apiService.getMealById(id);
          if (recipe != null) {
            recipes.add(recipe);
          }
        } catch (e) {
          print('Error loading recipe $id: $e');
          // Continue with other recipes even if one fails
        }
      }
      
      setState(() {
        _favoriteRecipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading favorites: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleFavorite(EnhancedRecipe recipe) async {
    final isFavorite = await _userInteractionService.toggleFavorite(recipe.id);
    
    if (!isFavorite) {
      // Recipe was removed from favorites
      setState(() {
        _favoriteRecipes.removeWhere((r) => r.id == recipe.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from favorites'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Favorites',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        drawer: const AppDrawer(currentRoute: '/favorites'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 72,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to see your favorites',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/favorites'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFavorites,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _favoriteRecipes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 72,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No favorite recipes yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Recipes you like will appear here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _favoriteRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = _favoriteRecipes[index];
                        return Dismissible(
                          key: Key(recipe.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) {
                            _toggleFavorite(recipe);
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecipeDetailScreen(recipe: recipe),
                                  ),
                                ).then((_) => _loadFavorites());
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  // Recipe image
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                    child: Image.network(
                                      recipe.thumbnail,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.error_outline, size: 40),
                                        );
                                      },
                                    ),
                                  ),
                                  
                                  // Recipe details
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recipe.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.category, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  recipe.category,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.public, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  recipe.area,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${recipe.ingredients.length} ingredients',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Delete button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.favorite,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _toggleFavorite(recipe),
                                    tooltip: 'Remove from favorites',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}