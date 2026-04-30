/// Conditional export: web build uses Web Audio API, other platforms are no-ops.
export 'sound_service_stub.dart'
    if (dart.library.js) 'sound_service_web.dart';
