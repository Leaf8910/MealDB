// lib/services/user_recipe_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/user_recipe_model.dart';
import 'package:image_picker/image_picker.dart';

class UserRecipeService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? get currentUser => _auth.currentUser;

  // Get user's recipes
  Future<List<UserRecipeModel>> getUserRecipes() async {
    try {
      final user = currentUser;
      
      if (user == null) {
        return [];
      }
      
      final snapshot = await _firestore
          .collection('user_recipes')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => UserRecipeModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user recipes: $e');
      return [];
    }
  }
  
  // Get a single recipe by ID
  Future<UserRecipeModel?> getRecipeById(String id) async {
    try {
      final doc = await _firestore
          .collection('user_recipes')
          .doc(id)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return UserRecipeModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting recipe: $e');
      return null;
    }
  }
  
  // Check if user is authenticated and sign in anonymously if needed
  Future<bool> _ensureAuthenticated() async {
    if (currentUser == null) {
      try {
        // Try to sign in anonymously if no user is logged in
        await _auth.signInAnonymously();
        return true;
      } catch (e) {
        debugPrint('Error signing in anonymously: $e');
        return false;
      }
    }
    return true;
  }
  
  Future<String?> uploadRecipeImage(File imageFile) async {
    try {
      final user = currentUser;
      
      if (user == null) {
        if (!await _ensureAuthenticated()) {
          throw Exception('User not logged in and anonymous login failed');
        }
      }
      
      final fileName = path.basename(imageFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destination = 'recipe_images/${currentUser!.uid}/${timestamp}_$fileName';
      
      // Create a reference to the file in Firebase Storage
      // IMPORTANT: Don't include the bucket URL in the ref method
      final ref = _storage.ref().child(destination);
      
      // Add metadata to the file
      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // Adjust based on your image type
        customMetadata: {'uploaded_by': currentUser!.uid},
      );
      
      // Upload with metadata and progress monitoring
      final uploadTask = ref.putFile(imageFile, metadata);
      
      // Add progress listener if needed
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('Upload progress: $progress%');
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() => debugPrint('Upload completed'));
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
  
  // Add a new recipe
  Future<UserRecipeModel?> addRecipe(UserRecipeModel recipe, {File? imageFile}) async {
    try {
      if (currentUser == null) {
        if (!await _ensureAuthenticated()) {
          throw Exception('User not logged in and anonymous login failed');
        }
      }
      
      // Upload image if provided
      String? imageUrl;
      if (imageFile != null) {
        debugPrint('Uploading image...');
        imageUrl = await uploadRecipeImage(imageFile);
      }
      
      // Prepare recipe with image URL
      final recipeToAdd = recipe.copyWith(
        thumbnailUrl: imageUrl ?? recipe.thumbnailUrl,
      );
      
      // Add to Firestore
      final docRef = await _firestore
          .collection('user_recipes')
          .add(recipeToAdd.toJson());
      
      // Get the created recipe with ID
      return recipeToAdd.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error adding recipe: $e');
      return null;
    }
  }
  
  // Update an existing recipe
  Future<UserRecipeModel?> updateRecipe(UserRecipeModel recipe, {File? imageFile}) async {
    try {
      if (recipe.id == null) {
        throw Exception('Recipe ID is required for updates');
      }
      
      if (currentUser == null) {
        if (!await _ensureAuthenticated()) {
          throw Exception('User not logged in and anonymous login failed');
        }
      }
      
      // Upload new image if provided
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadRecipeImage(imageFile);
      }
      
      // Prepare recipe with new image URL if available
      final recipeToUpdate = recipe.copyWith(
        thumbnailUrl: imageUrl ?? recipe.thumbnailUrl,
      );
      
      // Update in Firestore
      await _firestore
          .collection('user_recipes')
          .doc(recipe.id)
          .update(recipeToUpdate.toJson());
      
      return recipeToUpdate;
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      return null;
    }
  }
  
  // Delete a recipe
  Future<bool> deleteRecipe(String id) async {
    try {
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      // Get the recipe to check ownership and get image URL
      final recipeDoc = await _firestore
          .collection('user_recipes')
          .doc(id)
          .get();
      
      if (!recipeDoc.exists) {
        return false;
      }
      
      final recipe = UserRecipeModel.fromFirestore(recipeDoc);
      
      // Verify ownership
      if (recipe.userId != currentUser!.uid) {
        throw Exception('Not authorized to delete this recipe');
      }
      
      // Delete the image from storage if it exists
      if (recipe.thumbnailUrl != null && recipe.thumbnailUrl!.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(recipe.thumbnailUrl!);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting image: $e');
          // Continue with recipe deletion even if image deletion fails
        }
      }
      
      // Delete from Firestore
      await _firestore
          .collection('user_recipes')
          .doc(id)
          .delete();
      
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      return false;
    }
  }

  Future<String?> uploadWebImage(XFile webImage) async {
    try {
      if (currentUser == null) {
        if (!await _ensureAuthenticated()) {
          throw Exception('User not logged in and anonymous login failed');
        }
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'web_image_$timestamp.jpg';
      final destination = 'recipe_images/${currentUser!.uid}/$fileName';
      
      // Read the image data
      final bytes = await webImage.readAsBytes();
      
      // Create a reference to the file in Firebase Storage
      // IMPORTANT: Don't include the bucket URL in the ref method
      final ref = _storage.ref().child(destination);
      
      // Add metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded_by': currentUser!.uid},
      );
      
      // Upload the bytes
      final uploadTask = ref.putData(bytes, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('Upload progress: $progress%');
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() => debugPrint('Upload completed'));
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading web image: $e');
      return null;
    }
  }
  
  // Get public recipes from all users
  Future<List<UserRecipeModel>> getPublicRecipes({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('user_recipes')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => UserRecipeModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting public recipes: $e');
      return [];
    }
  }
  
  // Toggle public status of a recipe
  Future<UserRecipeModel?> togglePublicStatus(String id) async {
    try {
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      // Get the recipe
      final docRef = _firestore.collection('user_recipes').doc(id);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        return null;
      }
      
      final recipe = UserRecipeModel.fromFirestore(doc);
      
      // Verify ownership
      if (recipe.userId != currentUser!.uid) {
        throw Exception('Not authorized to modify this recipe');
      }
      
      // Create an updated timestamp
      final DateTime now = DateTime.now();
      
      // Toggle public status
      final isPublic = !recipe.isPublic;
      
      // Update in Firestore
      await docRef.update({
        'isPublic': isPublic,
        'updatedAt': Timestamp.fromDate(now),
      });
      
      // Return updated recipe model
      return recipe.copyWith(
        isPublic: isPublic,
        updatedAt: now,
      );
    } catch (e) {
      debugPrint('Error toggling public status: $e');
      return null;
    }
  }
}