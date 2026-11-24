import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A new random UUID (v4) — the row id on the device and on the server.
String newId() => _uuid.v4();

/// Whether [s] looks like a UUID (server columns are typed uuid).
bool isUuid(String? s) => s != null && RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);
