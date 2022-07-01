// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:watcher/src/watch_event.dart';

import 'environment.dart';
import 'pipeline.dart';
import 'utils.dart';

class BuildCommand extends Command<bool> with ArgUtils<bool> {
  BuildCommand() {
    argParser.addFlag(
        'watch',
        defaultsTo: false,
        abbr: 'w',
        help: 'Run the build in watch mode so it rebuilds whenever a change'
            'is made. Disabled by default.',
      );
    argParser.addFlag(
      'debug',
      defaultsTo: false,
      help: 'debug mode',
    );
  }

  @override
  String get name => 'build';

  @override
  String get description => 'Build the Flutter web engine.';

  bool get isWatchMode => boolArg('watch');
  bool get isDebug => boolArg('debug');

  @override
  FutureOr<bool> run() async {
    final FilePath libPath = FilePath.fromWebUi('lib');
    final Pipeline buildPipeline = Pipeline(steps: <PipelineStep>[
      GnPipelineStep(isDebug),
      NinjaPipelineStep(isDebug),
    ]);
    await buildPipeline.run();

    if (isWatchMode) {
      print('Initial build done!');
      print('Watching directory: ${libPath.relativeToCwd}/');
      await PipelineWatcher(
        dir: libPath.absolute,
        pipeline: buildPipeline,
        // Ignore font files that are copied whenever tests run.
        ignore: (WatchEvent event) => event.path.endsWith('.ttf'),
      ).start();
    }
    return true;
  }
}

/// Runs `gn`.
///
/// Not safe to interrupt as it may leave the `out/` directory in a corrupted
/// state. GN is pretty quick though, so it's OK to not support interruption.
class GnPipelineStep extends ProcessStep {


  @override
  String get description => 'gn';

  @override
  bool get isSafeToInterrupt => false;

  bool isDebug = false;

  GnPipelineStep(bool _isDebug)
  {
    isDebug = _isDebug;
  }

  @override
  Future<ProcessManager> createProcess() {
    print('Running gn...');
    String arg = '--runtime-mode=release';
    if(isDebug)
      arg = '';
    return startProcess(
      path.join(environment.flutterDirectory.path, 'tools', 'gn'),
      <String>[
        arg,
        if (Platform.isMacOS) '--xcode-symlinks',
        '--full-dart-sdk',
      ],
    );
  }
}

/// Runs `autoninja`.
///
/// Can be safely interrupted.
class NinjaPipelineStep extends ProcessStep {
  @override
  String get description => 'ninja';

  @override
  bool get isSafeToInterrupt => true;
  bool isDebug = false;

  NinjaPipelineStep(bool _isDebug)
  {
    isDebug = _isDebug;
  }
  @override
  Future<ProcessManager> createProcess() {
    print('Running autoninja...');
    String arg = environment.hostReleaseDir.path;
    if(isDebug)
      arg = environment.hostDebugUnoptDir.path;
    return startProcess(
      'autoninja',
      <String>[
        '-C',
        arg,
      ],
    );
  }
}
