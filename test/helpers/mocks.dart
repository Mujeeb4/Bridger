import 'package:mockito/annotations.dart';
import 'package:bridge_phone/services/ble_service.dart';
import 'package:bridge_phone/services/call_service.dart';
import 'package:bridge_phone/services/sms_service.dart';
import 'package:bridge_phone/services/notification_service.dart';
import 'package:bridge_phone/domain/repositories/settings_repository.dart';
import 'package:bridge_phone/domain/repositories/contact_repository.dart';

@GenerateMocks([
  BleService,
  CallService,
  SMSService,
  NotificationService,
  SettingsRepository,
  ContactRepository,
])
void main() {}
