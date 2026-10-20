import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;
  final String? notes;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
  });

  double get subtotal => product.price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      quantity: json['quantity'] ?? 1,
      notes: json['notes']);
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'notes': notes,
    };
  }

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? notes,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes);
  }
}

class Cart {
  final List<CartItem> items;

  Cart({this.items = const []});

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  double calculateTax({double taxRate = 0.10}) {
    return subtotal * taxRate;
  }

  double calculateService({double serviceRate = 0.05}) {
    return subtotal * serviceRate;
  }

  double calculateTotal({
    double taxRate = 0.10,
    double serviceRate = 0.05,
    double deliveryFee = 0,
    double discount = 0,
  }) {
    final tax = calculateTax(taxRate: taxRate);
    final service = calculateService(serviceRate: serviceRate);
    return subtotal + tax + service + deliveryFee - discount;
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => CartItem.fromJson(item))
              .toList()
          : []);
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
