import 'package:equatable/equatable.dart';

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

class ProductsLoadRequested extends ProductsEvent {
  const ProductsLoadRequested();
}

class ProductsSearchChanged extends ProductsEvent {
  final String query;

  const ProductsSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class ProductsNextPageRequested extends ProductsEvent {
  const ProductsNextPageRequested();
}

class ProductsRefreshRequested extends ProductsEvent {
  const ProductsRefreshRequested();
}
