/// Conditional export: web build uses Web Audio API, other platforms are no-ops.
library sound_service;

export 'sound_service_stub.dart'
    if (dart.library.js_interop) 'sound_service_web.dart';
