class Esp32Data {
  final double gas;
  final double luxes;
  final double setpoint;
  final int motorPos;
  final int motorMax;
  final int brillo;
  final bool modoAuto;
  final String rawResponse;

  Esp32Data({
    this.gas = 0.0,
    this.luxes = 0.0,
    this.setpoint = 500.0,
    this.motorPos = 0,
    this.motorMax = 4096,
    this.brillo = 0,
    this.modoAuto = true,
    this.rawResponse = '',
  });

  factory Esp32Data.fromJson(Map<String, dynamic> json, String raw) {
    // Parseo flexible para soportar tanto números enteros como flotantes o strings numéricos
    double parseDouble(dynamic value, double fallback) {
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? fallback;
    }

    int parseInt(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? fallback;
    }

    bool parseBool(dynamic value, bool fallback) {
      if (value == null) return fallback;
      if (value is bool) return value;
      final str = value.toString().toLowerCase();
      if (str == '1' || str == 'true' || str == 'auto') return true;
      if (str == '0' || str == 'false' || str == 'manual') return false;
      return fallback;
    }

    return Esp32Data(
      gas: parseDouble(json['gas'] ?? json['mq'] ?? json['gas_ppm'], 0.0),
      luxes: parseDouble(json['luxes'] ?? json['lux'] ?? json['luz'], 0.0),
      setpoint: parseDouble(json['setpoint'] ?? json['sp'], 500.0),
      motorPos: parseInt(json['motorPos'] ?? json['pos'] ?? json['posicion'], 0),
      motorMax: parseInt(json['motorMax'] ?? json['max'] ?? json['posMax'], 4096),
      brillo: parseInt(json['brillo'] ?? json['dimmer'] ?? json['pwm'], 0),
      modoAuto: parseBool(json['modoAuto'] ?? json['modo'] ?? json['auto'], true),
      rawResponse: raw,
    );
  }
}
