import 'threat_analysis.dart';

enum CyberRiskLevel { low, caution, high, critical, unknown }

enum CyberRiskColorToken { subtleGreen, amber, orange, red, neutralGray }

class CyberRiskSignal {
  const CyberRiskSignal({
    required this.level,
    required this.label,
    required this.score,
    required this.colorToken,
    required this.explanation,
    required this.recommendedAction,
  });

  factory CyberRiskSignal.fromResult(ThreatAnalysisResult result) {
    final CyberRiskLevel level = switch (result.verdict) {
      ThreatVerdict.low => CyberRiskLevel.low,
      ThreatVerdict.medium => CyberRiskLevel.caution,
      ThreatVerdict.high => CyberRiskLevel.high,
      ThreatVerdict.critical => CyberRiskLevel.critical,
      ThreatVerdict.unknown => CyberRiskLevel.unknown,
    };
    return CyberRiskSignal(
      level: level,
      label: switch (level) {
        CyberRiskLevel.low => 'LOW RISK',
        CyberRiskLevel.caution => 'CAUTION',
        CyberRiskLevel.high => 'HIGH RISK',
        CyberRiskLevel.critical => 'CRITICAL RISK',
        CyberRiskLevel.unknown => 'UNKNOWN',
      },
      score: result.riskScore,
      colorToken: switch (level) {
        CyberRiskLevel.low => CyberRiskColorToken.subtleGreen,
        CyberRiskLevel.caution => CyberRiskColorToken.amber,
        CyberRiskLevel.high => CyberRiskColorToken.orange,
        CyberRiskLevel.critical => CyberRiskColorToken.red,
        CyberRiskLevel.unknown => CyberRiskColorToken.neutralGray,
      },
      explanation: switch (level) {
        CyberRiskLevel.low =>
          'No significant warning signs were found during the initial checks.',
        CyberRiskLevel.caution =>
          'Some warning signs need your attention before you continue.',
        CyberRiskLevel.high =>
          'Multiple suspicious indicators were detected in this item.',
        CyberRiskLevel.critical =>
          'Several strong indicators require you to stop and protect your accounts.',
        CyberRiskLevel.unknown =>
          'Cyber Uday could not establish a reliable conclusion.',
      },
      recommendedAction: switch (level) {
        CyberRiskLevel.low =>
          'Continue only if you recognize and trust the sender.',
        CyberRiskLevel.caution =>
          'Verify the sender independently before opening or replying.',
        CyberRiskLevel.high || CyberRiskLevel.critical =>
          'Do not open links or provide credentials. Verify the sender independently.',
        CyberRiskLevel.unknown =>
          'Keep the item closed until a reliable analysis is available.',
      },
    );
  }

  final CyberRiskLevel level;
  final String label;
  final int score;
  final CyberRiskColorToken colorToken;
  final String explanation;
  final String recommendedAction;
}
