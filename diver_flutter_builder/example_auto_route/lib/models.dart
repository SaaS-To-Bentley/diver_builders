/// A plain runtime object handed to a page when navigating in-app.
///
/// auto_route can pass it straight to the page's constructor from Dart code,
/// but a URL has no way to carry it — which is what makes a route whose page
/// *requires* one ineligible for deeplinking.
class Cart {
  const Cart(this.itemCount);

  final int itemCount;
}
