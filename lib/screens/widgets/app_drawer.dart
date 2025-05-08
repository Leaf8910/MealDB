import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/auth_service.dart';
import '/screens/auth/login_screen.dart';
import '/screens/home_screen.dart';
import '/screens/categories_screen.dart';
import '/screens/cultures_screen.dart';
import '/screens/search_screen.dart';
import '/screens/favorites_screen.dart';
import '/screens/profile_screen.dart';
import '/screens/my_recipes_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    Key? key,
    this.currentRoute = '/',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // User profile header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.orange,
              ),
              accountName: Text(
                user?.displayName ?? 'Guest',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              accountEmail: Text(
                user?.email ?? 'Sign in to access all features',
                style: const TextStyle(color: Colors.white),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: user?.photoURL != null
                    ? ClipOval(
                        child: Image.network(
                          user!.photoURL!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, size: 40, color: Colors.orange),
                        ),
                      )
                    : const Icon(Icons.person, size: 40, color: Colors.orange),
              ),
            ),
            // Menu items
            _buildMenuItem(
              context,
              'Home',
              Icons.home,
              currentRoute == '/',
              () => _navigateTo(context, const HomeScreen()),
            ),
            _buildMenuItem(
              context,
              'Categories',
              Icons.category,
              currentRoute == '/categories',
              () => _navigateTo(context, const CategoriesScreen()),
            ),
            _buildMenuItem(
              context,
              'Cuisines',
              Icons.public,
              currentRoute == '/cultures',
              () => _navigateTo(context, const CulturesScreen()),
            ),
            _buildMenuItem(
              context,
              'Search',
              Icons.search,
              currentRoute == '/search',
              () => _navigateTo(context, const SearchScreen()),
            ),
            if (user != null)
              _buildMenuItem(
                context,
                'Favorites',
                Icons.favorite,
                currentRoute == '/favorites',
                () => _navigateTo(context, const FavoritesScreen()),
              ),
            if (user != null)
              _buildMenuItem(
                context,
                'Profile',
                Icons.person,
                currentRoute == '/profile',
                () => _navigateTo(context, const ProfileScreen()),
              ),

            if (user != null)
              _buildMenuItem(
                context,
                'My Recipes',
                Icons.restaurant_menu,
                currentRoute == '/my_recipes',
                () => _navigateTo(context, const MyRecipesScreen()),
              ),
            if (user != null)
              _buildMenuItem(
                context,
                'Sign Out',
                Icons.logout,
                false,
                () => _signOut(context),
              ),
            if (user == null)
              _buildMenuItem(
                context,
                'Sign In',
                Icons.login,
                false,
                () => _navigateTo(context, const LoginScreen()),
              ),

              
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.orange : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.orange : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close drawer
    if (currentRoute != screen.runtimeType.toString()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }
}