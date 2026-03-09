import '../models/recommend_recipe.dart';

final List<RecommendRecipe> seedRecipes = [
  RecommendRecipe(
    id: 'seed_1',
    name: 'Chicken Salad Bowl',
    cuisine: 'American',
    calories: 420,
    ingredients: ['chicken', 'lettuce', 'tomato', 'olive oil'],
    imageUrl: null,
  ),
  RecommendRecipe(
    id: 'seed_2',
    name: 'Sushi Bowl',
    cuisine: 'Japanese',
    calories: 520,
    ingredients: ['rice', 'salmon', 'seaweed', 'soy sauce'],
    imageUrl: null,
  ),
  RecommendRecipe(
    id: 'seed_3',
    name: 'Tofu Stir Fry',
    cuisine: 'Chinese',
    calories: 390,
    ingredients: ['tofu', 'broccoli', 'garlic', 'soy sauce'],
    imageUrl: null,
  ),
];