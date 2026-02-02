import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/core/services/voip_service.dart';
import 'package:kyber_launcher/gen/generated_bindings.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class VivoxService with ChangeNotifier {
  final _logger = Logger('vivox_service');

  Isolate? _isolate;
  ReceivePort? _recv;
  SendPort? _isoSend;

  Future<void> _downloadLibrary({String? path}) async {
    await Dio().download(
      'https://s3.kyber.gg/frontend-assets/mc/vivoxsdk.dll',
      path,
    );
  }

  Future<VivoxService> getInstance() async {
    final moduleDir = FileHelper.getModuleDirectory().path;

    if (!kDebugMode && Platform.isMacOS) {
      return this;
    }

    late String libPath;
    if (kDebugMode) {
      if (Platform.isMacOS) {
        libPath = join(moduleDir, 'libvivoxsdk.dylib');
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = join(tempDir.path, 'vivoxsdk.dll');
        if (!File(tempFile).existsSync()) {
          await _downloadLibrary(path: tempFile);
        }
        libPath = join(tempDir.path, 'vivoxsdk.dll');
      }
    } else {
      final exePath = Platform.resolvedExecutable;
      final exeDir = dirname(exePath);
      libPath = Platform.isMacOS
          ? join(exeDir, 'libvivoxsdk.dylib')
          : join(exeDir, 'vivoxsdk.dll');

      if (!File(libPath).existsSync()) {
        final tempDir = await getTemporaryDirectory();
        await _downloadLibrary(path: join(tempDir.path, 'vivoxsdk.dll'));
        libPath = join(tempDir.path, 'vivoxsdk.dll');
      }
    }

    _logger.fine('Using Vivox library at: $libPath');

    _recv = ReceivePort('vivox_main_recv');
    _isolate = await Isolate.spawn(
      _vivoxIsolateEntry,
      {
        'mainSend': _recv!.sendPort,
        'libPath': libPath,
      },
      debugName: 'vivox_isolate',
    );

    _recv!.listen((msg) {
      if (msg is Map) {
        final type = msg['type'];
        switch (type) {
          case 'ready':
            _isoSend = msg['sendPort'] as SendPort;
          case 'input':
            {
              final list = (msg['devices'] as List<VoipDevice>).toList();
              sl.get<VoipService>().setInputDevices(list);
            }
          case 'output':
            {
              final list = (msg['devices'] as List<VoipDevice>).toList();
              sl.get<VoipService>().setOutputDevices(list);
            }
          case 'error':
            _logger.severe('Vivox isolate error: ${msg['message']}');
        }
      }
    });

    return this;
  }

  @override
  void dispose() {
    try {
      _isoSend?.send({'cmd': 'shutdown'});
    } catch (_) {}
    _isoSend = null;

    _recv?.close();
    _recv = null;

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    super.dispose();
  }
}

Future<void> _vivoxIsolateEntry(Map args) async {
  // TODO: in the long run, it would probably better to move this to a separate package to have seperate windows, macos and linux implementations
  /*final SendPort mainSend = args['mainSend'] as SendPort;
  final String libPath = args['libPath'] as String;

  final ctrl = ReceivePort('vivox_iso_ctrl');
  mainSend.send({'type': 'ready', 'sendPort': ctrl.sendPort});

  DynamicLibrary? vivoxLib;
  NativeLibrary? lib;
  Pointer<vx_sdk_config>? configPtr;
  NativeCallable<Void Function(Pointer<Void>)>? callback;

  void sendError(String msg) =>
      mainSend.send({'type': 'error', 'message': msg});

  void _issueRequest(NativeLibrary L, Pointer<vx_req_base_t> basePtr) {
    final countPtr = calloc<Int>();
    try {
      final rc = L.vx_issue_request3(basePtr, countPtr);
      if (rc != 0) {
        throw Exception('vx_issue_request3 failed: $rc');
      }
    } finally {
      calloc.free(countPtr);
    }
  }

  void _captureInputDevices(NativeLibrary L) {
    final holder = calloc<Pointer<vx_req_aux_get_capture_devices_t>>();
    final rc = L.vx_req_aux_get_capture_devices_create(holder);
    if (rc != 0) {
      calloc.free(holder);
      throw Exception('create capture req failed: $rc');
    }
    final basePtr = holder.value.cast<vx_req_base_t>();
    _issueRequest(L, basePtr);
    calloc.free(holder);
  }

  void _captureOutputDevices(NativeLibrary L) {
    final holder = calloc<Pointer<vx_req_aux_get_render_devices_t>>();
    final rc = L.vx_req_aux_get_render_devices_create(holder);
    if (rc != 0) {
      calloc.free(holder);
      throw Exception('create render req failed: $rc');
    }
    final basePtr = holder.value.cast<vx_req_base_t>();
    _issueRequest(L, basePtr);
    calloc.free(holder);
  }

  void _onSdkMessage(Pointer<Void> _) {
    if (lib == null) return;
    final L = lib!;
    final msgPtrPtr = calloc<Pointer<vx_message_base>>();
    try {
      final code = L.vx_get_message(msgPtrPtr);
      if (code != 0 || msgPtrPtr.value == nullptr) return;

      final msg = msgPtrPtr.value;
      if (msg.ref.type == vx_message_type.msg_response) {
        final resp = msg.cast<vx_resp_base_t>();
        if (resp.ref.return_code == 1) {
          final errStr = L
              .vx_get_error_string(resp.ref.status_code)
              .cast<Utf8>()
              .toDartString();
          sendError('Vivox response error: ${resp.ref.status_code} $errStr');
        } else {
          final t = resp.ref.type;
          if (t == vx_response_type.resp_aux_get_capture_devices) {
            final cap = resp.cast<vx_resp_aux_get_capture_devices>();
            final n = cap.ref.count;
            final list = <VoipDevice>[];
            final devs = cap.ref.capture_devices;
            for (var i = 0; i < n; i++) {
              final d = devs[i].ref;
              final id = d.device.cast<Utf8>().toDartString();
              final name = d.display_name.cast<Utf8>().toDartString();
              list.add(VoipDevice(id: id, name: name));
            }
            final idx = list.indexWhere(
              (e) => e.name == 'Default System Device',
            );
            if (idx > 0) {
              final tmp = list.removeAt(idx);
              list.insert(0, tmp);
            }

            mainSend.send({'type': 'input', 'devices': list});
            return;
          } else if (t == vx_response_type.resp_aux_get_render_devices) {
            final cap = resp.cast<vx_resp_aux_get_render_devices>();
            final n = cap.ref.count;
            final list = <VoipDevice>[];
            final devs = cap.ref.render_devices;
            for (var i = 0; i < n; i++) {
              final d = devs[i].ref;
              final id = d.device.cast<Utf8>().toDartString();
              final name = d.display_name.cast<Utf8>().toDartString();
              list.add(
                VoipDevice(
                  id: id,
                  name: name,
                ),
              );
            }

            final idx = list.indexWhere(
              (e) => e.name == 'Default System Device',
            );
            if (idx > 0) {
              final tmp = list.removeAt(idx);
              list.insert(0, tmp);
            }

            mainSend.send({'type': 'output', 'devices': list});
            return;
          }
        }
      } else if (msg.ref.type == vx_message_type.msg_event) {
        final evt = msg.cast<vx_evt_base_t>();
        if (evt.ref.type == vx_event_type.evt_audio_device_hot_swap) {
          _captureInputDevices(L);
          _captureOutputDevices(L);
        }
      }
    } catch (e) {
      sendError('callback exception: $e');
    } finally {
      if (msgPtrPtr.value != nullptr) {
        lib?.vx_destroy_message(msgPtrPtr.value);
      }
      calloc.free(msgPtrPtr);
    }
  }

  void _cleanup() {
    try {
      if (lib != null && lib!.vx_is_initialized() != 0) {
        lib!.vx_uninitialize();
      }
    } catch (_) {}

    try {
      callback?.close();
    } catch (_) {}
    callback = null;

    try {
      if (configPtr != null) {
        calloc.free(configPtr!);
      }
    } catch (_) {}
    configPtr = null;
  }

  Future<void> _init() async {
    vivoxLib = DynamicLibrary.open(libPath);
    lib = NativeLibrary(vivoxLib!);

    if (lib!.vx_is_initialized() != 0) {
      lib!.vx_uninitialize();
    }

    final cfg = calloc<vx_sdk_config>();
    configPtr = cfg;

    final rcDef = lib!.vx_get_default_config3(cfg, sizeOf<vx_sdk_config>());
    if (rcDef != 0) {
      calloc.free(cfg);
      configPtr = null;
      throw Exception('vx_get_default_config3 failed: $rcDef');
    }

    callback = NativeCallable<Void Function(Pointer<Void>)>.listener(
      _onSdkMessage,
    );
    cfg.ref.pf_sdk_message_callback = callback!.nativeFunction;

    final rcInit = lib!.vx_initialize3(cfg, sizeOf<vx_sdk_config>());
    if (rcInit != 0) {
      callback?.close();
      calloc.free(cfg);
      configPtr = null;
      throw Exception('vx_initialize3 failed: $rcInit');
    }

    _captureInputDevices(lib!);
    _captureOutputDevices(lib!);
  }

  await () async {
    try {
      await _init();
    } catch (e) {
      sendError('init failed: $e');
    }
  }();
   */
}

extension MoveElement<T> on List<T> {
  void move(int from, int to) {
    RangeError.checkValidIndex(from, this, 'from', length);
    RangeError.checkValidIndex(to, this, 'to', length);
    final element = this[from];
    if (from < to) {
      setRange(from, to, this, from + 1);
    } else {
      setRange(to + 1, from + 1, this, to);
    }
    this[to] = element;
  }
}
