class PhraseItem {
  final String text;
  final String iconName;

  PhraseItem({
    required this.text,
    required this.iconName,
  });
}

class PhraseBoard {
  final String id;
  final String name;
  final String contextTrigger;
  final String? triggerTimeStart;
  final String? triggerTimeEnd;
  final String icon;
  final List<PhraseItem> items;

  PhraseBoard({
    required this.id,
    required this.name,
    required this.contextTrigger,
    this.triggerTimeStart,
    this.triggerTimeEnd,
    required this.icon,
    required this.items,
  });
}
