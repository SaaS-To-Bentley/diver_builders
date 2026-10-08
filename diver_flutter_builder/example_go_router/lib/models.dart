/// Plain runtime objects passed to routes through go_router's `$extra`.
///
/// They cannot be encoded in a URL, which is what makes a route carrying a
/// *required* `$extra` parameter ineligible for deeplinking.
class User {
  const User(this.name);

  final String name;
}

class Cart {
  const Cart(this.itemCount);

  final int itemCount;
}

/// A fixed set of choices. As a route parameter it becomes an `enum` query
/// parameter, its `values` written the way go_router_builder puts them into a
/// URL: each constant's name, kebab-cased.
enum SortOrder { relevance, priceLow, priceHigh }
