// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.grind;

import 'dart:async';
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:librato/librato.dart';

void main(List<String> args) {
  task('init', defaultInit);
  task('build', build, ['init']);
  task('deploy', deploy, ['build']);
  task('clean', defaultClean);

  startGrinder(args);
}

/// Build the `web/dartpad.html` entrypoint.
build(GrinderContext context) {
  Pub.build(context, directories: ['web']);

  File outFile = joinFile(BUILD_DIR, ['web', 'dartpad.dart.js']);
  context.log('${outFile.path} compiled to ${_printSize(outFile)}');

  // Delete the build/web/packages directory.
  deleteEntity(getDir('build/web/packages'));

  // Reify the symlinks.
  // cp -R -L packages build/web/packages
  runProcess(context, 'cp',
      arguments: ['-R', '-L', 'packages', 'build/web/packages']);

  return _uploadCompiledStats(context, outFile.lengthSync());
}

/// Prepare the app for deployment.
void deploy(GrinderContext context) {
  context.log('execute: `appcfg.py update build/web`');
}

Future _uploadCompiledStats(GrinderContext context, num length) {
  Map env = Platform.environment;

  if (env.containsKey('LIBRATO_USER') && env.containsKey('TRAVIS_COMMIT')) {
    Librato librato = new Librato.fromEnvVars();
    Map stats = { 'dartpad.dart.js': length};
    context.log('Uploading stats to ${librato.url}');
    return librato.postStats(stats, groupName: env['TRAVIS_COMMIT']);
  } else {
    return new Future.value();
  }
}

String _printSize(File file) => '${(file.lengthSync() + 1023) ~/ 1024}k';
