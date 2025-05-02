// lib/screens/recipe_detail_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/enhanced_recipe.dart';
import '../models/review_model.dart';
import '../services/auth_service.dart';
import '../services/user_interaction_service.dart';
import '../services/pdf_service.dart';
import 'auth/login_screen.dart';
import 'review_screen.dart';
import '../services/user_recipe_service.dart';
import '../models/user_recipe_model.dart';
import 'create_recipe_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final EnhancedRecipe recipe;
   final bool isUserRecipe; 
  final String? userRecipeId;

  const RecipeDetailScreen({
    Key? key,
    required this.recipe,
    this.isUserRecipe = false,
    this.userRecipeId,
  }) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  final UserInteractionService _userInteractionService = UserInteractionService();
  final PdfService _pdfService = PdfService();
  
  late TabController _tabController;
  bool _isFavorite = false;
  bool _isLoading = true;
  double? _userRating;
  List<ReviewModel> _reviews = [];
  Map<String, dynamic> _recipeMetadata = {
    'averageRating': 0.0,
    'ratingCount': 0,
    'favoriteCount': 0,
    'commentCount': 0,
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkFavoriteStatus();
    _loadRecipeMetadata();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // Check if recipe is in user's favorites
  Future<void> _checkFavoriteStatus() async {
    // Check if user is logged in
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      final isFavorite = await _userInteractionService.isFavorite(widget.recipe.id);
      final userRating = await _userInteractionService.getUserRating(widget.recipe.id);
      
      setState(() {
        _isFavorite = isFavorite;
        _userRating = userRating;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking favorite status: $e');
      setState(() {
        _isLoading = false;
      });
    }



  }
  

// Edit recipe
void _editRecipe() {
  if (!widget.isUserRecipe || widget.userRecipeId == null) return;

  // Navigate to CreateRecipeScreen with the current recipe for editing
  // You'll need to import 'create_recipe_screen.dart' and 'user_recipe_service.dart'
  final userRecipeService = Provider.of<UserRecipeService>(context, listen: false);
  userRecipeService.getRecipeById(widget.userRecipeId!).then((userRecipe) {
    if (userRecipe != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateRecipeScreen(recipe: userRecipe),
        ),
      ).then((updatedRecipe) {
        if (updatedRecipe != null) {
          // Refresh the screen with updated recipe data
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(
                recipe: (updatedRecipe as UserRecipeModel).toEnhancedRecipe(),
                isUserRecipe: true,
                userRecipeId: updatedRecipe.id,
              ),
            ),
          );
        }
      });
    }
  });
}

// Confirm deletion
void _confirmDelete() {
  if (!widget.isUserRecipe || widget.userRecipeId == null) return;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Recipe'),
      content: const Text(
        'Are you sure you want to delete this recipe? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _deleteRecipe();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

// Delete recipe
void _deleteRecipe() async {
  if (!widget.isUserRecipe || widget.userRecipeId == null) return;

  try {
    final userRecipeService = Provider.of<UserRecipeService>(context, listen: false);
    final success = await userRecipeService.deleteRecipe(widget.userRecipeId!);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe deleted successfully')),
      );
      // Navigate back to the previous screen
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete recipe')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// Toggle public/private status
void _togglePublicStatus() async {
  if (!widget.isUserRecipe || widget.userRecipeId == null) return;

  try {
    final userRecipeService = Provider.of<UserRecipeService>(context, listen: false);
    final updatedRecipe = await userRecipeService.togglePublicStatus(widget.userRecipeId!);
    
    if (updatedRecipe != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedRecipe.isPublic
                ? 'Recipe is now public'
                : 'Recipe is now private',
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}


  // Load recipe metadata and reviews
  Future<void> _loadRecipeMetadata() async {
    try {
      final metadata = await _userInteractionService.getRecipeMetadata(widget.recipe.id);
      final reviews = await _userInteractionService.getReviews(widget.recipe.id);
      
      setState(() {
        _recipeMetadata = metadata;
        _reviews = reviews;
      });
    } catch (e) {
      print('Error loading recipe metadata: $e');
    }
  }
  
  // Toggle favorite status
  Future<void> _toggleFavorite() async {
    // Check if user is logged in
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      // Show login prompt
      _showLoginDialog();
      return;
    }
    
    try {
      final isFavorite = await _userInteractionService.toggleFavorite(widget.recipe.id);
      
      setState(() {
        _isFavorite = isFavorite;
        _recipeMetadata['favoriteCount'] = isFavorite
            ? (_recipeMetadata['favoriteCount'] ?? 0) + 1
            : (_recipeMetadata['favoriteCount'] ?? 1) > 0 
                ? (_recipeMetadata['favoriteCount'] ?? 1) - 1
                : 0;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? 'Added to favorites!'
                : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  // Rate recipe
  Future<void> _rateRecipe(double rating) async {
    // Check if user is logged in
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      // Show login prompt
      _showLoginDialog();
      return;
    }
    
    try {
      await _userInteractionService.rateRecipe(widget.recipe.id, rating);
      
      // Update UI
      setState(() {
        _userRating = rating;
        
        // Update metadata with new rating
        final int ratingCount = _recipeMetadata['ratingCount'] ?? 0;
        final double oldAverage = _recipeMetadata['averageRating'] ?? 0.0;
        
        if (_userRating == null) {
          // First time rating
          _recipeMetadata['ratingCount'] = ratingCount + 1;
          _recipeMetadata['averageRating'] = 
              (oldAverage * ratingCount + rating) / (ratingCount + 1);
        } else {
          // Updating existing rating
          _recipeMetadata['averageRating'] = 
              (oldAverage * ratingCount - (_userRating ?? 0) + rating) / ratingCount;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating saved!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  // Show login dialog
  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text(
          'You need to sign in to use this feature. Would you like to sign in now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
  
  // Share recipe
  Future<void> _shareRecipe() async {
    final String shareText = '''
Check out this amazing recipe for ${widget.recipe.name}!
Category: ${widget.recipe.category}
Cuisine: ${widget.recipe.area}
''';
    
    await Share.share(
      widget.recipe.youtubeUrl != null
          ? '$shareText\nWatch how to make it: ${widget.recipe.youtubeUrl}'
          : shareText,
      subject: 'Amazing Recipe: ${widget.recipe.name}',
    );
  }
  
  // Generate PDF for the recipe
  // Generate PDF for the recipe
Future<void> _generatePdf() async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Generating PDF...')),
  );
  
  try {
    final result = await _pdfService.generateRecipePdf(widget.recipe);
    
    if (mounted) {
      if (kIsWeb) {
        // For web, we can't share a file directly
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generated! Web sharing is still under development.')),
        );
      } else {
        // For mobile, we can share the file
        final file = result as File; // Cast to File since we know it's a File on mobile
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF generated successfully!'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                Share.shareXFiles(
                  [XFile(file.path)],
                  text: 'Recipe for ${widget.recipe.name}',
                );
              },
            ),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }
}
  
  // Open YouTube video
  Future<void> _openYoutubeVideo() async {
    if (widget.recipe.youtubeUrl == null || widget.recipe.youtubeUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video available for this recipe')),
      );
      return;
    }
    
    final Uri url = Uri.parse(widget.recipe.youtubeUrl!);
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video link')),
        );
      }
    }
  }
  
  // Get image URL for ingredient
  String _getIngredientImageUrl(String ingredient) {
    // TheMealDB provides ingredient images at this URL pattern
    // Convert ingredient name to lowercase, remove spaces and special characters
    final formattedName = ingredient.toLowerCase().trim()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_') // Replace multiple underscores with single
        .replaceAll(RegExp(r'^_|_$'), ''); // Remove leading/trailing underscores
    
    return 'https://www.themealdb.com/images/ingredients/$formattedName.png';
  }
  
  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    widget.recipe.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(0.0, 0.0),
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Recipe image
                      Image.network(
                        widget.recipe.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(Icons.error_outline, size: 40),
                            ),
                          );
                        },
                      ),
                      // Gradient overlay
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black54,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  // User recipe management options
                  if (widget.isUserRecipe && widget.userRecipeId != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editRecipe();
                        } else if (value == 'delete') {
                          _confirmDelete();
                        } else if (value == 'togglePublic') {
                          _togglePublicStatus();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Edit Recipe'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'togglePublic',
                          child: ListTile(
                            leading: Icon(Icons.public),
                            title: Text('Toggle Public/Private'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete Recipe', style: TextStyle(color: Colors.red)),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  // Existing actions for all recipes
                  if (widget.recipe.youtubeUrl != null && widget.recipe.youtubeUrl!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Colors.white),
                      onPressed: _openYoutubeVideo,
                      tooltip: 'Watch Video',
                    ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    onPressed: _generatePdf,
                    tooltip: 'Generate PDF',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _shareRecipe,
                    tooltip: 'Share',
                  ),
                ],
              ),
              
              // Recipe info and tabs
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic info and ratings
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category and Area chips with user recipe indicator
                          Wrap(
                            spacing: 8,
                            children: [
                              if (widget.isUserRecipe)
                                Chip(
                                  label: const Text('My Recipe'),
                                  avatar: const Icon(Icons.person, size: 16),
                                  backgroundColor: Colors.blue.shade100,
                                ),
                              Chip(
                                label: Text(widget.recipe.category),
                                avatar: const Icon(Icons.category, size: 16),
                              ),
                              Chip(
                                label: Text(widget.recipe.area),
                                avatar: const Icon(Icons.public, size: 16),
                              ),
                            ],
                          ),
                          
                          // Rest of your existing content...
                        ],
                      ),
                    ),
                    
                    // Tabs
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Ingredients'),
                        Tab(text: 'Instructions'),
                        Tab(text: 'Reviews'),
                      ],
                    ),
                    
                    // Tab content - use a sized container with a reasonable height
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5, // Use a percentage of screen height
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildIngredientsTab(),
                          _buildInstructionsTab(),
                          _buildReviewsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    floatingActionButton: _tabController.index == 2
        ? FloatingActionButton(
            onPressed: () => _navigateToReviewScreen(),
            tooltip: 'Write Review',
            child: const Icon(Icons.rate_review),
          )
        : null,
  );
}

  // Ingredients tab content with images
  Widget _buildIngredientsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.recipe.ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = widget.recipe.ingredients.keys.elementAt(index);
        final measure = widget.recipe.ingredients[ingredient];
        final imageUrl = _getIngredientImageUrl(ingredient);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Ingredient image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.orange,
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Ingredient details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        measure ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Instructions tab content
  Widget _buildInstructionsTab() {
    // Split instructions into steps
    final steps = widget.recipe.instructions.split('\r\n')
        .where((step) => step.trim().isNotEmpty)
        .toList();
    
    // If no line breaks, try to use periods as separators
    if (steps.length <= 1) {
      final stepsByPeriod = widget.recipe.instructions
          .split('.')
          .where((step) => step.trim().isNotEmpty)
          .toList();
      
      if (stepsByPeriod.length > 1) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stepsByPeriod.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.orange,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${stepsByPeriod[index].trim()}.',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    }
    
    if (steps.length > 1) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: steps.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.orange,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[index].trim(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // If can't split into steps, show as a single card
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.recipe.instructions,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }
  }
  
  // Reviews tab content
  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to review this recipe!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToReviewScreen(),
              icon: const Icon(Icons.add),
              label: const Text('Write a Review'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: review.userPhotoUrl != null
                          ? NetworkImage(review.userPhotoUrl!)
                          : null,
                      child: review.userPhotoUrl == null
                          ? Text(
                              review.userName.isNotEmpty
                                  ? review.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDate(review.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RatingBar.builder(
                      initialRating: review.rating,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 16,
                      ignoreGestures: true,
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      onRatingUpdate: (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(review.comment),
              ],
            ),
          ),
        );
      },
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
  
  // Navigate to review screen
  void _navigateToReviewScreen() {
    // Check if user is logged in
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      // Show login prompt
      _showLoginDialog();
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          recipe: widget.recipe,
          userRating: _userRating ?? 0.0,
          onReviewAdded: (review) {
            setState(() {
              _reviews.insert(0, review);
              _recipeMetadata['commentCount'] = 
                  (_recipeMetadata['commentCount'] ?? 0) + 1;
            });
          },
        ),
      ),
    );
  }
}