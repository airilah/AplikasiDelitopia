/// Global formatter for brand names across Delitopia app
/// Converts uppercase/raw database brand names into clean canonical display names:
/// - SUSHIKUN -> Sushikun
/// - AH BANG -> Ah Bang
/// - TOMOKO -> Tomoko
/// - DELITOPIA -> Delitopia
String formatBrandName(dynamic rawName) {
  if (rawName == null) return '';
  final name = rawName.toString().trim();
  if (name.isEmpty) return '';

  final upper = name.toUpperCase();
  if (upper == 'SUSHIKUN') return 'Sushikun';
  if (upper == 'AH BANG' || upper == 'AHBANG' || upper == 'AH_BANG') return 'Ah Bang';
  if (upper == 'TOMOKO') return 'Tomoko';
  if (upper == 'DELITOPIA') return 'Delitopia';

  // For any other brands, convert to Title Case
  return name.split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}
