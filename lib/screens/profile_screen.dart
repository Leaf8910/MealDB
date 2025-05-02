// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/user_interaction_service.dart';
import '../models/review_model.dart';
import '../models/enhanced_recipe.dart';
import 'widgets/app_drawer.dart';
import 'recipe_detail_screen.dart';
import 'auth/login_screen.dart';
import '../services/enhanced_meal_api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EnhancedMealApiService _apiService = EnhancedMealApiService();
  final UserInteractionService _userInteractionService = UserInteractionService();
  
  late TabController _tabController;
  bool _isLoading = false;
  bool _isLoadingFavorites = false;
  List<ReviewModel> _userReviews = [];
  List<EnhancedRecipe> _favoriteRecipes = [];
  
  // Edit profile state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadUserReviews();
    _loadFavorites();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  void _loadUserData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }
  }
  
  Future<void> _loadUserReviews() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create a compound query with a single field (userId)
      // This should avoid the missing index error
      final QuerySnapshot reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      // Sort the results in memory
      final reviews = reviewsSnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
      
      // Sort by createdAt in descending order
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _userReviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadFavorites() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      return;
    }
    
    setState(() {
      _isLoadingFavorites = true;
    });
    
    try {
      // Get favorite recipe IDs
      final favoriteIds = await _userInteractionService.getFavoriteIds();
      
      if (favoriteIds.isEmpty) {
        setState(() {
          _favoriteRecipes = [];
          _isLoadingFavorites = false;
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
        _isLoadingFavorites = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() {
        _isLoadingFavorites = false;
      });
    }
  }
  
  Future<void> _toggleFavorite(EnhancedRecipe recipe) async {
    try {
      final isFavorite = await _userInteractionService.toggleFavorite(recipe.id);
      
      // Update the favorites list
      if (!isFavorite) {
        setState(() {
          _favoriteRecipes.removeWhere((r) => r.id == recipe.id);
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // try {
    //   final authService = Provider.of<AuthService>(context, listen: false);
    //   await authService.updateUserProfile(
    //     name: _nameController.text.trim(),
    //   );
      
    //   setState(() {
    //     _isEditing = false;
    //     _isLoading = false;
    //   });
      
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('Profile updated successfully!'),
    //         duration: Duration(seconds: 2),
    //       ),
    //     );
    //   }
    // } catch (e) {
    //   setState(() {
    //     _errorMessage = 'Error updating profile: $e';
    //     _isLoading = false;
    //   });
    // }
  }
  
  Future<void> _signOut() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
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
            'Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        drawer: const AppDrawer(currentRoute: '/profile'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle,
                size: 72,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to view your profile',
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
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/profile'),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Profile header
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.orange,
                  child: Center(
                    child: Column(
                      children: [
                        // Profile picture
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? Text(
                                  user.displayName?.isNotEmpty == true
                                      ? user.displayName![0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // User name
                        if (_isEditing)
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Name',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _updateProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.orange,
                                      ),
                                      child: const Text('Save'),
                                    ),
                                    const SizedBox(width: 16),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = false;
                                          _nameController.text = user.displayName ?? '';
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                                if (_errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade100,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user.displayName ?? 'User',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                tooltip: 'Edit Profile',
                              ),
                            ],
                          ),
                        Text(
                          user.email ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Tabs
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'My Reviews'),
                    Tab(text: 'Favorites'),
                  ],
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Reviews tab
                      _buildReviewsTab(),
                      
                      // Favorites tab
                      _buildFavoritesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildReviewsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_userReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your reviews will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userReviews.length,
      itemBuilder: (context, index) {
        final review = _userReviews[index];
        return FutureBuilder(
          future: _apiService.getMealById(review.recipeId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            
            final recipe = snapshot.data;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: recipe != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailScreen(recipe: recipe),
                          ),
                        ).then((_) => _loadFavorites()); // Refresh favorites after returning
                      }
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recipe image if available
                          if (recipe != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                recipe.thumbnail,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.error_outline),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(width: 16),
                          // Review details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe?.name ?? 'Recipe not found',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    for (int i = 0; i < 5; i++)
                                      Icon(
                                        i < review.rating.floor()
                                            ? Icons.star
                                            : i < review.rating
                                                ? Icons.star_half
                                                : Icons.star_border,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(review.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (recipe != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Category: ${recipe.category}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Cuisine: ${recipe.area}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        review.comment,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildFavoritesTab() {
    if (_isLoadingFavorites) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_favoriteRecipes.isEmpty) {
      return Center(
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
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _favoriteRecipes.length,
      itemBuilder: (context, index) {
        final recipe = _favoriteRecipes[index];
        return _buildFavoriteRecipeCard(recipe);
      },
    );
  }
  
  Widget _buildFavoriteRecipeCard(EnhancedRecipe recipe) {
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
          ).then((_) => _loadFavorites()); // Refresh favorites after returning
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
                    child: IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 18,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _toggleFavorite(recipe),
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
                  const SizedBox(height: 2),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to format dates
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}