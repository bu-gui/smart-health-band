class DeviceInfo {
  final String firmwareVersion;
  final String hardwareVersion;
  final String serialNumber;
  final String model;

  const DeviceInfo({
    this.firmwareVersion = '',
    this.hardwareVersion = '',
    this.serialNumber = '',
    this.model = '',
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      firmwareVersion: json['fw'] as String? ?? '',
      hardwareVersion: json['hw'] as String? ?? '',
      serialNumber: json['serial'] as String? ?? '',
      model: json['model'] as String? ?? '',
    );
  }

  factory DeviceInfo.empty() => DeviceInfo();
}
