/// Categorized offline content-moderation engine for CampusOS Mesh Chat.
///
/// Runs locally with zero internet connectivity on both outbound and inbound
/// messages, normalizing leetspeak, zero-width characters, and symbol obfuscation.
enum MeshModerationSeverity {
  none,
  moderate,
  high,
  critical;

  String get wireName => name.toUpperCase();

  static MeshModerationSeverity fromString(String? value) {
    switch ((value ?? '').toUpperCase().trim()) {
      case 'CRITICAL':
        return MeshModerationSeverity.critical;
      case 'HIGH':
        return MeshModerationSeverity.high;
      case 'MODERATE':
        return MeshModerationSeverity.moderate;
      default:
        return MeshModerationSeverity.none;
    }
  }
}

class MeshModerationVerdict {
  /// 'CLEAN', 'FLAGGED', 'QUARANTINED', or 'HIDDEN_BY_ADMIN'
  final String status;
  final MeshModerationSeverity severity;

  /// 'NONE', 'CRIME_THREAT', 'HARASSMENT', 'EXPLICIT', 'SPAM'
  final String category;
  final List<String> reasons;

  const MeshModerationVerdict({
    required this.status,
    required this.severity,
    required this.category,
    this.reasons = const [],
  });

  static const MeshModerationVerdict clean = MeshModerationVerdict(
    status: 'CLEAN',
    severity: MeshModerationSeverity.none,
    category: 'NONE',
  );

  bool get isClean => status == 'CLEAN';
  bool get isFlaggedOrQuarantined => status != 'CLEAN';
  bool get isCritical => severity == MeshModerationSeverity.critical;
}

class MeshModerationException implements Exception {
  final MeshModerationVerdict verdict;
  final String message;

  const MeshModerationException({
    required this.verdict,
    required this.message,
  });

  @override
  String toString() => message;
}

class _ModerationRule {
  final String category;
  final MeshModerationSeverity severity;
  final String label;
  final RegExp pattern;
  final List<String> compactTerms;

  const _ModerationRule({
    required this.category,
    required this.severity,
    required this.label,
    required this.pattern,
    this.compactTerms = const [],
  });
}

class MeshModerationFilter {
  static final RegExp _invisibleChars = RegExp(r'[\u200B-\u200F\u202A-\u202E\uFEFF]');
  static final RegExp _nonAlnumSpace = RegExp(r'[^a-z0-9\s]');
  static final RegExp _multiSpace = RegExp(r'\s+');

  static const Map<String, String> _leetMap = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    '@': 'a',
    r'$': 's',
    '!': 'i',
  };

  static final List<_ModerationRule> _rules = [
    _ModerationRule(
      category: 'CRIME_THREAT',
      severity: MeshModerationSeverity.critical,
      label: 'Explosive / Bomb / Arson Threat',
      pattern: RegExp(
        r'\b(bomb|ied|explosive|detonate|blow\s+up|plant\s+a\s+bomb|burn\s+down|arson|pipe\s+bomb|grenade|molotov)\b',
      ),
      compactTerms: ['plantabomb', 'pipebomb', 'blowupthe'],
    ),
    _ModerationRule(
      category: 'CRIME_THREAT',
      severity: MeshModerationSeverity.critical,
      label: 'Armed Violence / Weapon / Murder Threat',
      pattern: RegExp(
        r'\b(gun|pistol|rifle|shotgun|firearm|weapon|knife|dagger|stab|shoot|shooting|mass\s+shoot|kill|murder|assassinate|slit|kidnap|abduct|hostage|rape|molest|sexual\s+assault|robbery)\b',
      ),
      compactTerms: ['shootupcampus', 'bringagun', 'killyou', 'murderyou', 'stabyou'],
    ),
    _ModerationRule(
      category: 'CRIME_THREAT',
      severity: MeshModerationSeverity.critical,
      label: 'Self-Harm / Suicide Risk',
      pattern: RegExp(
        r'\b(suicide|kill\s+myself|commit\s+suicide|end\s+my\s+life|want\s+to\s+die|self\s+harm)\b',
      ),
      compactTerms: ['killmyself', 'commitsuicide', 'endmylife', 'selfharm'],
    ),
    _ModerationRule(
      category: 'CRIME_THREAT',
      severity: MeshModerationSeverity.critical,
      label: 'Illegal Drugs / Narcotics',
      pattern: RegExp(
        r'\b(weed|ganja|charas|marijuana|cocaine|meth|heroin|mdma|lsd|fentanyl|narcotics|drug\s+deal(?:er|ing)?|sell(?:ing)?\s+drugs|buy\s+drugs)\b',
      ),
      compactTerms: ['selldrugs', 'drugdealer', 'buycocaine', 'buymeth'],
    ),
    _ModerationRule(
      category: 'CRIME_THREAT',
      severity: MeshModerationSeverity.high,
      label: 'Extortion / Theft / Fraud',
      pattern: RegExp(
        r'\b(blackmail|extort|ransom|rob|theft|steal|burglary|assault|threaten|doxx|bribe|scam|fraud|leak\s+(?:your|her|his)\s+(?:nudes|photos|address)|pay\s+me\s+or\s+else)\b',
      ),
      compactTerms: ['blackmail', 'extort', 'leaknudes'],
    ),
    _ModerationRule(
      category: 'HARASSMENT',
      severity: MeshModerationSeverity.high,
      label: 'Severe Harassment / Hate Slur',
      pattern: RegExp(
        r'\b(faggot|nigger|retard|kys|kill\s+yourself|die\s+bitch|worthless\s+piece\s+of\s+shit)\b',
      ),
      compactTerms: ['killyourself'],
    ),
    _ModerationRule(
      category: 'HARASSMENT',
      severity: MeshModerationSeverity.moderate,
      label: 'Abusive / Profane Language',
      pattern: RegExp(
        r'\b(fuck|fucking|fucker|motherfucker|shit|bullshit|asshole|bitch|bastard|slut|whore|cunt|dick|idiot|stupid|moron|chutiya|madarchod|behenchod|bhosdike|gandu|harami|kamina)\b',
      ),
      compactTerms: ['motherfucker', 'madarchod', 'behenchod'],
    ),
    _ModerationRule(
      category: 'EXPLICIT',
      severity: MeshModerationSeverity.moderate,
      label: 'Sexually Explicit Content',
      pattern: RegExp(
        r'\b(nudes|send\s+nudes|onlyfans|porn|xxx|sex\s+tape)\b',
      ),
      compactTerms: ['sendnudes', 'sextape'],
    ),
    _ModerationRule(
      category: 'SPAM',
      severity: MeshModerationSeverity.moderate,
      label: 'Suspected Scam / Phishing',
      pattern: RegExp(
        r'\b(guaranteed\s+crypto\s+profit|double\s+your\s+money|send\s+otp|share\s+your\s+password|click\s+to\s+claim\s+prize)\b',
      ),
      compactTerms: ['sendotp', 'doubleyourmoney'],
    ),
  ];

  static String _normalize(String input) {
    var out = input.replaceAll(_invisibleChars, '').toLowerCase();
    final buffer = StringBuffer();
    for (int i = 0; i < out.length; i++) {
      final ch = out[i];
      buffer.write(_leetMap[ch] ?? ch);
    }
    out = buffer.toString().replaceAll(_nonAlnumSpace, ' ');
    return out.replaceAll(_multiSpace, ' ').trim();
  }

  /// Evaluates message text against safety & moderation rules.
  static MeshModerationVerdict evaluate(String text, {bool isEncrypted = false}) {
    if (isEncrypted || text.trim().isEmpty) {
      return MeshModerationVerdict.clean;
    }

    final spaced = _normalize(text);
    final compact = spaced.replaceAll(' ', '');
    final reasons = <String>[];
    var highestSeverity = MeshModerationSeverity.none;
    var primaryCategory = 'NONE';

    for (final rule in _rules) {
      var hit = rule.pattern.hasMatch(spaced);
      if (!hit && rule.compactTerms.isNotEmpty) {
        hit = rule.compactTerms.any((term) => compact.contains(term));
      }
      if (hit) {
        reasons.add(rule.label);
        if (rule.severity.index > highestSeverity.index) {
          highestSeverity = rule.severity;
          primaryCategory = rule.category;
        }
      }
    }

    if (highestSeverity == MeshModerationSeverity.none) {
      return MeshModerationVerdict.clean;
    }

    final status = (highestSeverity == MeshModerationSeverity.critical ||
            highestSeverity == MeshModerationSeverity.high)
        ? 'QUARANTINED'
        : 'FLAGGED';

    return MeshModerationVerdict(
      status: status,
      severity: highestSeverity,
      category: primaryCategory,
      reasons: reasons,
    );
  }
}
