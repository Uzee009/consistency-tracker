class QuoteService {
  QuoteService._();
  static final QuoteService instance = QuoteService._();

  int _manualIndex = -1;

  final List<String> quotes = [
    "Small daily disciplines repeated over time lead to massive results.",
    "Don't break the chain. Every completed day is an investment in your future.",
    "You do not rise to the level of your goals. You fall to the level of your systems.",
    "Consistency is the true foundation of trust in yourself.",
    "Action creates motivation, not the other way around.",
    "A year from now, you will wish you had stayed consistent today.",
    "Focus on the process, and the outcomes will take care of themselves.",
    "Discipline is choosing between what you want now and what you want most.",
    "Momentum is built one checkmark at a time.",
    "Show up, even when you don't feel like it. Especially when you don't feel like it.",
    "Success isn't always about greatness. It's about consistency.",
    "The secret of your future is hidden in your daily routine.",
    "Never miss twice. Missing once is an accident; missing twice is a new habit.",
    "Energy flows where attention goes.",
  ];

  String getQuote({
    required int streak,
    required int pendingTasks,
    required bool isCompleted,
  }) {
    if (isCompleted) {
      return "🔥 Streak preserved! Fantastic work crushing today's goals.";
    }
    if (pendingTasks == 1) {
      return "Almost there! Just 1 more task to lock in today's momentum.";
    }

    if (_manualIndex >= 0) {
      return quotes[_manualIndex % quotes.length];
    }

    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return quotes[dayOfYear % quotes.length];
  }

  void nextQuote() {
    if (_manualIndex < 0) {
      final now = DateTime.now();
      _manualIndex = now.difference(DateTime(now.year, 1, 1)).inDays;
    }
    _manualIndex = (_manualIndex + 1) % quotes.length;
  }
}
