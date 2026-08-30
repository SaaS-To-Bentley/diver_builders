/// Annotation attached to a go_router route class to enrich the generated
/// `app_urls.json` (produced by `diver_flutter_builder`) with a human-readable
/// [name] and [description].
class DiverRoute {
  const DiverRoute({this.name = "", this.description = ""});

  final String name;
  final String description;
}
