import 'dart:io';

import 'package:collection/collection.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<void> run({
  required Directory packageDirectory,
  Directory? directoryWithAnalysisOptions,
}) async {
  final config = await findPackageConfig(packageDirectory);

  if (config == null) {
    print('No package was found in directory `${packageDirectory.path}`');
    exitCode = 1;
    return;
  }

  directoryWithAnalysisOptions ??= Directory.current;

  final analysisOptionsUri =
      directoryWithAnalysisOptions.uri.resolve('analysis_options.yaml');

  final bundle = _lintsFromUri(analysisOptionsUri, config);

  final toKeep = bundle.explicit.toSet()..removeAll(bundle.included);

  print(toKeep.join('\n'));
}

class _LintBundle {
  _LintBundle({required this.explicit, required this.included});

  final Set<String> explicit;
  final Set<String> included;

  Set<String> get allLints => explicit.union(included);
}

_LintBundle _lintsFromUri(
  Uri analysisOptionsUri,
  PackageConfig packageConfig,
) {
  if (analysisOptionsUri.isScheme('file')) {
    return _lintsFromFile(p.fromUri(analysisOptionsUri), packageConfig);
  }

  if (analysisOptionsUri.isScheme('package')) {
    return _analysisOptionsFromPackage(analysisOptionsUri, packageConfig);
  }

  throw UnimplementedError('for uri $analysisOptionsUri');
}

_LintBundle _lintsFromFile(String path, PackageConfig packageConfig) {
  final yaml = _openYamlMap(path);

  final included = <String>{};
  final includeKey = yaml['include'] as String?;
  if (includeKey != null) {
    final includeValue = _lintsFromUri(Uri.parse(includeKey), packageConfig);
    included.addAll(includeValue.allLints);
  }

  final linterValue = yaml['linter'] as Map?;

  final explicit = <String>{};
  if (linterValue != null) {
    final rulesValue = linterValue['rules'] as List?;
    if (rulesValue != null) {
      explicit.addAll(rulesValue.cast<String>());
    }
  }

  return _LintBundle(explicit: explicit, included: included);
}

YamlMap _openYamlMap(String path) {
  final analysisOptionsFile = File(path);

  final analysisOptionsContent = analysisOptionsFile.readAsStringSync();

  final aoYaml =
      loadYaml(analysisOptionsContent, sourceUrl: analysisOptionsFile.uri)
          as YamlMap;

  return aoYaml;
}

_LintBundle _analysisOptionsFromPackage(
  Uri includeUri,
  PackageConfig packageConfig,
) {
  if (!includeUri.isScheme('package')) {
    throw '`$includeUri` is not a package!';
  }

  final pkg = includeUri.pathSegments.first;

  final usedLintsPkg =
      packageConfig.packages.firstWhereOrNull((p) => p.name == pkg);

  if (usedLintsPkg == null) {
    throw StateError('Could not find the package `$pkg` in package config');
  }

  final yamlPath = usedLintsPkg.root.resolve(
    p.joinAll(
      ['lib', ...includeUri.pathSegments.skip(1)],
    ),
  );

  return _lintsFromFile(p.fromUri(yamlPath), packageConfig);
}
