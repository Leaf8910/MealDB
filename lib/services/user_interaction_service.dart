import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/review_model.dart';
import '../models/enhanced_recipe.dart';

class UserInteractionService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? get currentUser => _auth.currentUser;
  
  //add or remove favorite recipe
  Future<bool> toggleFavorite(String recipeId) async {
    try {
      final User? user = currentUser;
      
      if (user == null) {
        return false;
      }
      
      final DocumentReference userRef = _firestore.collection('users').doc(user.uid);
      final DocumentSnapshot userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        return false;
      }
      
      final UserModel userModel = UserModel.fromFirestore(userDoc);
      final bool isFavorite = userModel.favorites.contains(recipeId);
      
      //adding/removing from favorites
      if (isFavorite) {
        // Remove from favorites
        await userRef.update({
          'favorites': FieldValue.arrayRemove([recipeId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        //decrement favorite count in recipes collection
        await _firestore.collection('recipes').doc(recipeId).update({
          'favoriteCount': FieldValue.increment(-1),
        });
        
        return false; 
      } else {
        await userRef.update({
          'favorites': FieldValue.arrayUnion([recipeId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('recipes').doc(recipeId).update({
          'favoriteCount': FieldValue.increment(1),
        }).catchError((error) {
          // If recipe document doesn't exist yet, create it
          if (error is FirebaseException && error.code == 'not-found') {
            return _firestore.collection('recipes').doc(recipeId).set({
              'id': recipeId,
              'favoriteCount': 1,
              'ratingCount': 0,
              'averageRating': 0.0,
              'commentCount': 0,
            });
          }
          throw error;
        });
        
        return true; // Now a favorite
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      rethrow;
    }
  }
  
  Future<bool> isFavorite(String recipeId) async {
    try {
      final User? user = currentUser;
      
      if (user == null) {
        return false;
      }
      
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        return false;
      }
      
      final UserModel userModel = UserModel.fromFirestore(userDoc);
      return userModel.favorites.contains(recipeId);
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }
  
  //users favorite recipes
  Future<List<String>> getFavoriteIds() async {
    try {
      final User? user = currentUser;
      
      if (user == null) {
        return [];
      }
      
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        return [];
      }
      
      final UserModel userModel = UserModel.fromFirestore(userDoc);
      return userModel.favorites;
    } catch (e) {
      debugPrint('Error getting favorite recipe IDs: $e');
      return [];
    }
  }
  
  // Rate a recipe
  Future<void> rateRecipe(String recipeId, double rating) async {
    try {
      final User? user = currentUser;
      
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      final String ratingId = '${recipeId}_${user.uid}';
      final DocumentReference ratingRef = _firestore.collection('ratings').doc(ratingId);
      final DocumentSnapshot ratingDoc = await ratingRef.get();
      
      final DocumentReference recipeRef = _firestore.collection('recipes').doc(recipeId);
      final DocumentSnapshot recipeDoc = await recipeRef.get();
      
      if (ratingDoc.exists) {
        // Update existing rating
        final RatingModel oldRating = RatingModel.fromFirestore(ratingDoc);
        
        // Update rating document
        await ratingRef.update({
          'rating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (recipeDoc.exists) {
          // Update recipe document with adjusted average rating
          final Map<String, dynamic> recipeData = recipeDoc.data() as Map<String, dynamic>;
          final double oldAverage = (recipeData['averageRating'] ?? 0.0).toDouble();
          final int ratingCount = (recipeData['ratingCount'] ?? 0);

          double newAverage;
          if (ratingCount == 1) {
            newAverage = rating;
          } else {
            newAverage = ((oldAverage * ratingCount) - oldRating.rating + rating) / ratingCount;
          }
          
          await recipeRef.update({
            'averageRating': newAverage,
          });
        } else {

          await recipeRef.set({
            'id': recipeId,
            'averageRating': rating,
            'ratingCount': 1,
            'favoriteCount': 0,
            'commentCount': 0,
          });
        }
      } else {
        // Create new rating
        final RatingModel newRating = RatingModel(
          id: ratingId,
          recipeId: recipeId,
          userId: user.uid,
          rating: rating,
        );
        

        await ratingRef.set(newRating.toJson());
        

        if (recipeDoc.exists) {
          final Map<String, dynamic> recipeData = recipeDoc.data() as Map<String, dynamic>;
          final double oldAverage = (recipeData['averageRating'] ?? 0.0).toDouble();
          final int ratingCount = (recipeData['ratingCount'] ?? 0);
          

          final double newAverage = ((oldAverage * ratingCount) + rating) / (ratingCount + 1);
          
          await recipeRef.update({
            'averageRating': newAverage,
            'ratingCount': FieldValue.increment(1),
          });
        } else {

          await recipeRef.set({
            'id': recipeId,
            'averageRating': rating,
            'ratingCount': 1,
            'favoriteCount': 0,
            'commentCount': 0,
          });
        }
      }
    } catch (e) {
      debugPrint('Error rating recipe: $e');
      rethrow;
    }
  }
  

  Future<double?> getUserRating(String recipeId) async {
    try {
      final User? user = currentUser;
      
      if (user == null) {
        return null;
      }
      
      final String ratingId = '${recipeId}_${user.uid}';
      final DocumentSnapshot ratingDoc = await _firestore
          .collection('ratings')
          .doc(ratingId)
          .get();
      
      if (ratingDoc.exists) {
        final RatingModel rating = RatingModel.fromFirestore(ratingDoc);
        return rating.rating;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting user rating: $e');
      return null;
    }
  }
  
  // Add a review for a recipe
  Future<ReviewModel?> addReview(String recipeId, String comment, double rating) async {
    try {
      final User? user = currentUser;
      
      if (user == null) {
        throw Exception('User not logged in');
      }
      

      await rateRecipe(recipeId, rating);
      
      final DocumentReference reviewRef = _firestore.collection('reviews').doc();
      
      final ReviewModel review = ReviewModel(
        id: reviewRef.id,
        recipeId: recipeId,
        userId: user.uid,
        userName: user.displayName ?? 'User',
        userPhotoUrl: user.photoURL,
        comment: comment,
        rating: rating,
      );
      
      await reviewRef.set(review.toJson());
      
      await _firestore.collection('recipes').doc(recipeId).update({
        'commentCount': FieldValue.increment(1),
      }).catchError((error) {
        if (error is FirebaseException && error.code == 'not-found') {
          return _firestore.collection('recipes').doc(recipeId).set({
            'id': recipeId,
            'commentCount': 1,
            'favoriteCount': 0,
            'ratingCount': 1,
            'averageRating': rating,
          });
        }
        throw error;
      });
      
      return review;
    } catch (e) {
      debugPrint('Error adding review: $e');
      rethrow;
    }
  }
  
  // Get reviews for a recipe
  Future<List<ReviewModel>> getReviews(String recipeId) async {
    try {
      final QuerySnapshot reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('recipeId', isEqualTo: recipeId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return reviewsSnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting reviews: $e');
      return [];
    }
  }
  
  // Get recipe data
  Future<Map<String, dynamic>> getRecipeMetadata(String recipeId) async {
    try {
      final DocumentSnapshot recipeDoc = await _firestore
          .collection('recipes')
          .doc(recipeId)
          .get();
      
      if (recipeDoc.exists) {
        final Map<String, dynamic> data = recipeDoc.data() as Map<String, dynamic>;
        return {
          'averageRating': (data['averageRating'] ?? 0.0).toDouble(),
          'ratingCount': data['ratingCount'] ?? 0,
          'favoriteCount': data['favoriteCount'] ?? 0,
          'commentCount': data['commentCount'] ?? 0,
        };
      }
      
      return {
        'averageRating': 0.0,
        'ratingCount': 0,
        'favoriteCount': 0,
        'commentCount': 0,
      };
    } catch (e) {
      debugPrint('Error getting recipe metadata: $e');
      return {
        'averageRating': 0.0,
        'ratingCount': 0,
        'favoriteCount': 0,
        'commentCount': 0,
      };
    }
  }
}