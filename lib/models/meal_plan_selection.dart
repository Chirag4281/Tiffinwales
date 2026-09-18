// lib/models/meal_plan_selection.dart

class MealPlanSelection {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String? imageBase64;
  final String category;
  final bool isVeg;
  final int quantity;
  final Map<String, dynamic> originalItem;

  MealPlanSelection({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.imageBase64,
    required this.category,
    required this.isVeg,
    this.quantity = 1,
    required this.originalItem,
  });

  MealPlanSelection copyWith({
    int? quantity,
  }) {
    return MealPlanSelection(
      id: id,
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
      imageBase64: imageBase64,
      category: category,
      isVeg: isVeg,
      quantity: quantity ?? this.quantity,
      originalItem: originalItem,
    );
  }

  double get totalPrice => price * quantity;

  Map<String, dynamic> toCartItem() {
    return {
      'item_name': name,
      'item_price': price,
      'quantity': quantity,
      'category': category,
      'is_veg': isVeg,
      'image_url': imageUrl,
      'image_base64': imageBase64,
    };
  }
}