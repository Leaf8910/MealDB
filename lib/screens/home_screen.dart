// screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/meal_api_service.dart';
import 'recipe_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MealApiService _apiService = MealApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Recipe> _recipes = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get random recipes to show on initial load
      final List<Recipe> recipes = [];
      for (int i = 0; i < 5; i++) {
        recipes.add(await _apiService.getRandomMeal());
      }
      
      final categories = await _apiService.getCategories();
      
      setState(() {
        _recipes = recipes;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }
  
  Future<void> _searchRecipes(String query) async {
    if (query.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _selectedCategory = null;
    });
    
    try {
      final recipes = await _apiService.searchMeals(query);
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: $e')),
      );
    }
  }
  
  Future<void> _loadCategoryRecipes(String category) async {
    setState(() {
      _isLoading = true;
      _selectedCategory = category;
      _searchController.clear();
    });
    
    try {
      final recipes = await _apiService.getMealsByCategory(category);
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading category: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Finder'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recipes',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onSubmitted: _searchRecipes,
            ),
          ),
          
          // Categories horizontal list
          SizedBox(
            height: 50,
            child: _isLoading && _categories.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            if (selected) {
                              _loadCategoryRecipes(category);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          
          // Recipes list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recipes.isEmpty
                    ? const Center(child: Text('No recipes found'))
                    : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _recipes.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final recipe = _recipes[index];
                        return RecipeCard(
                          recipe: recipe,
                          onTap: () {
                            Navigator.push( 
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(recipe: recipe),
                              ),
                            );
                          },
                        );
                      },
                    )
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadInitialData,
        tooltip: 'Random Recipes',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({
    Key? key,
    required this.recipe,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                recipe.thumbnail,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 180,
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.error_outline, size: 40),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Category: ${recipe.category}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Cuisine: ${recipe.area}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: recipe.ingredients.keys
                        .take(3)
                        .map((ingredient) => Chip(
                              label: Text(
                                ingredient,
                                style: const TextStyle(fontSize: 12),
                              ),
                              padding: const EdgeInsets.all(0),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                  if (recipe.ingredients.length > 3)
                    Text(
                      '+ ${recipe.ingredients.length - 3} more ingredients',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}