// lib/screens/cultures_screen.dart
import 'package:flutter/material.dart';
import 'dart:math'; // Import for min function
import '../models/enhanced_recipe.dart';
import '../services/enhanced_meal_api_service.dart';
import '../services/user_interaction_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'widgets/app_drawer.dart';
import 'recipe_detail_screen.dart';

class CulturesScreen extends StatefulWidget {
  final String? selectedCulture;
  
  const CulturesScreen({
    Key? key,
    this.selectedCulture,
  }) : super(key: key);

  @override
  State<CulturesScreen> createState() => _CulturesScreenState();
}

class _CulturesScreenState extends State<CulturesScreen> {
  final EnhancedMealApiService _apiService = EnhancedMealApiService();
  final UserInteractionService _userInteractionService = UserInteractionService();
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _cultures = [];
  List<EnhancedRecipe> _recipes = [];
  List<EnhancedRecipe> _filteredRecipes = [];
  bool _isLoading = true;
  bool _isLoadingRecipes = false;
  String? _selectedCulture;
  String? _errorMessage;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _selectedCulture = widget.selectedCulture;
    _loadCultures();
    // Load some default recipes if no culture is selected
    if (_selectedCulture == null) {
      _loadDefaultRecipes();
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Load default recipes (random)
  Future<void> _loadDefaultRecipes() async {
    setState(() {
      _isLoadingRecipes = true;
      _errorMessage = null;
    });
    
    try {
      final recipes = await _apiService.getMultipleRandomMeals(10);
      
      setState(() {
        _recipes = recipes;
        _filteredRecipes = recipes;
        _isLoadingRecipes = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading recipes: $e';
        _isLoadingRecipes = false;
      });
    }
  }
  
  Future<void> _loadCultures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final cultures = await _apiService.getAreas();
      
      setState(() {
        _cultures = cultures;
        _isLoading = false;
      });
      
      // If a culture was pre-selected, load its recipes
      if (_selectedCulture != null) {
        _loadRecipesByCulture(_selectedCulture!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading cultures: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadRecipesByCulture(String culture) async {
    setState(() {
      _isLoadingRecipes = true;
      _selectedCulture = culture;
      _errorMessage = null;
      _searchQuery = ''; // Reset search when changing culture
      _searchController.clear();
    });
    
    try {
      final recipes = await _apiService.getMealsByArea(culture);
      
      setState(() {
        _recipes = recipes;
        _filteredRecipes = recipes;
        _isLoadingRecipes = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading recipes: $e';
        _isLoadingRecipes = false;
      });
    }
  }
  
  // Filter recipes based on search query
  void _filterRecipes(String query) {
    setState(() {
      _searchQuery = query;
      
      if (query.isEmpty) {
        _filteredRecipes = _recipes;
      } else {
        _filteredRecipes = _recipes.where((recipe) => 
          recipe.name.toLowerCase().contains(query.toLowerCase()) ||
          recipe.category.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }
  
  // Toggle favorite for a recipe
  Future<void> _toggleFavorite(EnhancedRecipe recipe) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      // Show login prompt
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save favorites')),
      );
      return;
    }
    
    try {
      final isFavorite = await _userInteractionService.toggleFavorite(recipe.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Added to favorites' : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh the UI
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search cuisines...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
          onChanged: _filterRecipes,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              _showFilterDialog();
            },
            tooltip: 'Filter',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/cultures'),
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
                        onPressed: _loadCultures,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Cultures horizontal list
                    Container(
                      height: 104, // Slightly reduced height
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _cultures.length + 1, // +1 for "All" option
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // "All" option
                            final isSelected = _selectedCulture == null;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCulture = null;
                                });
                                _loadDefaultRecipes();
                              },
                              child: Container(
                                width: 60,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade700,
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? Border.all(color: Colors.orange, width: 3)
                                            : null,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "All",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "All",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10, // Smaller font size
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          final culture = _cultures[index - 1];
                          final isSelected = _selectedCulture == culture;
                          
                          return GestureDetector(
                            onTap: () => _loadRecipesByCulture(culture),
                            child: Container(
                              width: 60, // Reduced width
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.primaries[(index - 1) % Colors.primaries.length],
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: Colors.orange, width: 3)
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        culture.substring(0, min(2, culture.length)),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18, // Slightly smaller
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6), // Reduced spacing
                                  Text(
                                    culture,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10, // Smaller font size
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected ? Colors.orange : Colors.black,
                                    ),
                                    maxLines: 1, // Ensure single line
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Recipes grid
                    Expanded(
                      child: _isLoadingRecipes
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredRecipes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.no_meals,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                      ? 'No recipes found for "$_searchQuery"'
                                      : _selectedCulture != null
                                        ? 'No recipes found for $_selectedCulture cuisine'
                                        : 'No recipes found',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _filteredRecipes.length,
                              itemBuilder: (context, index) {
                                final recipe = _filteredRecipes[index];
                                return _buildRecipeCard(recipe);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
  
  // Show filter dialog
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Center(
                    child: Text(
                      'Filter Recipes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Cuisine selection
                  const Text(
                    'Cuisine',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Cuisine chips scrollable row
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cultures.length,
                      itemBuilder: (context, index) {
                        final culture = _cultures[index];
                        final isSelected = _selectedCulture == culture;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(culture),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  _selectedCulture = culture;
                                } else {
                                  _selectedCulture = null;
                                }
                              });
                            },
                            checkmarkColor: Colors.white,
                            selectedColor: Colors.orange,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sort options
                  const Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 8.0,
                    children: [
                      FilterChip(
                        label: const Text('Name (A-Z)'),
                        selected: false,
                        onSelected: (selected) {
                          setModalState(() {
                            _filteredRecipes.sort((a, b) => a.name.compareTo(b.name));
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Name (Z-A)'),
                        selected: false,
                        onSelected: (selected) {
                          setModalState(() {
                            _filteredRecipes.sort((a, b) => b.name.compareTo(a.name));
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Most Ingredients'),
                        selected: false,
                        onSelected: (selected) {
                          setModalState(() {
                            _filteredRecipes.sort((a, b) => b.ingredients.length.compareTo(a.ingredients.length));
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Least Ingredients'),
                        selected: false,
                        onSelected: (selected) {
                          setModalState(() {
                            _filteredRecipes.sort((a, b) => a.ingredients.length.compareTo(b.ingredients.length));
                          });
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        if (_selectedCulture != null) {
                          _loadRecipesByCulture(_selectedCulture!);
                        } else {
                          _loadDefaultRecipes();
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildRecipeCard(EnhancedRecipe recipe) {
    return Card(
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
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image with favorite button
            Stack(
              children: [
                // Recipe image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    recipe.thumbnail,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.error_outline, size: 40),
                        ),
                      );
                    },
                  ),
                ),
                
                // Favorite button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FutureBuilder<bool>(
                      future: _userInteractionService.isFavorite(recipe.id),
                      builder: (context, snapshot) {
                        final isFavorite = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : null,
                          ),
                          iconSize: 18,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => _toggleFavorite(recipe),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            // Recipe details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }
}