String normalizeAnswer(String s) {
  final lower = s.toLowerCase().trim();
  final noPunc = lower.replaceAll(RegExp(r"[^\w\s']"), ' ');
  return noPunc.replaceAll(RegExp(r"\s+"), ' ').trim();
}

List<String> tokenizeWords(String sentence) {
  final cleaned = sentence
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .replaceAll(RegExp(r"\s+"), ' ')
      .trim();
  if (cleaned.isEmpty) return [];
  return cleaned.split(' ');
}

String blankOutFirstOccurrence({
  required String sentence,
  required String wordOrPhrase,
}) {
  final re = RegExp(RegExp.escape(wordOrPhrase), caseSensitive: false);
  final match = re.firstMatch(sentence);
  if (match == null) return sentence;
  return sentence.replaceRange(match.start, match.end, '____');
}