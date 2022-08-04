import 'dart:io';

import 'package:args/args.dart';
import 'package:lint_cleanup/lint_cleanup.dart';

Future<void> main(List<String> arguments) async {
  final result = _parser.parse(arguments);

  final pkgDir = result['package-dir'] as String?;

  Directory pkgDirectory;
  if (pkgDir == null) {
    pkgDirectory = Directory.current;
  } else {
    pkgDirectory = Directory(pkgDir);
    if (!pkgDirectory.existsSync()) {
      print('Provided package-dir `$pkgDir` does not exist!');
      exitCode = 1;
      return;
    }
  }

  return run(
    packageDirectory: pkgDirectory,
  );
}

final _parser = ArgParser()..addOption('package-dir', abbr: 'p');
