// lib/services/meal_plan_manager.dart

import 'package:flutter/foundation.dart';
import '../models/meal_plan_selection.dart';

class MealPlanManager extends ChangeNotifier {
  final Map<String, MealPlanSelection> _selectedItems = {};

  Map<String, MealPlanSelection> get selectedItems => Map.unmodifiable(_selectedItems);

  int get itemCount => _selectedItems.length;

  int get totalQuantity => _selectedItems.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _selectedItems.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  bool get isEmpty => _selectedItems.isEmpty;

  bool get isNotEmpty => _selectedItems.isNotEmpty;

  bool isSelected(String id) => _selectedItems.containsKey(id);

  int getQuantity(String id) => _selectedItems[id]?.quantity ?? 0;

  void addItem(MealPlanSelection item) {
    if (_selectedItems.containsKey(item.id)) {
      _selectedItems[item.id] = _selectedItems[item.id]!.copyWith(
        quantity: _selectedItems[item.id]!.quantity + 1,
      );
    } else {
      _selectedItems[item.id] = item;
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _selectedItems.remove(id);
    notifyListeners();
  }

  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      _selectedItems.remove(id);
    } else if (_selectedItems.containsKey(id)) {
      _selectedItems[id] = _selectedItems[id]!.copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void incrementQuantity(String id) {
    if (_selectedItems.containsKey(id)) {
      _selectedItems[id] = _selectedItems[id]!.copyWith(
        quantity: _selectedItems[id]!.quantity + 1,
      );
      notifyListeners();
    }
  }

  void decrementQuantity(String id) {
    if (_selectedItems.containsKey(id)) {
      final currentQty = _selectedItems[id]!.quantity;
      if (currentQty <= 1) {
        _selectedItems.remove(id);
      } else {
        _selectedItems[id] = _selectedItems[id]!.copyWith(
          quantity: currentQty - 1,
        );
      }
      notifyListeners();
    }
  }

  void clear() {
    _selectedItems.clear();
    notifyListeners();
  }

  List<MealPlanSelection> getItemsList() {
    return _selectedItems.values.toList();
  }

  /// Convert selected items to cart items for bulk add
  List<Map<String, dynamic>> toCartItems() {
    return _selectedItems.values.map((item) => item.toCartItem()).toList();
  }
}