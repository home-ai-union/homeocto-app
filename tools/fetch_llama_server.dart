#!/usr/bin/env dart

/// Fetch llama-server pre-built binaries from llama.cpp GitHub releases
/// and install them to Android jniLibs directory.
///
/// Usage:
///   dart run tools/fetch_llama_server.dart [--tag b9247] [--dest path/to/jniLibs]
///
/// This script downloads the Android arm64 binary package from:
///   https://github.com/ggml-org/llama.cpp/releases
///
/// The package contains:
///   - llama-server (executable, renamed to libllama-server.so)
///   - libllama.so, libggml.so, and other dependencies
///
/// All .so files are installed to jniLibs/arm64-v8a/ for APK packaging.

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

const defaultRepo = 'ggerganov/llama.cpp';
const defaultArch = 'arm64';
const binaryName = 'libllama-server.so';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('repo', abbr: 'r', defaultsTo: defaultRepo)
    ..addOption('tag', abbr: 't', defaultsTo: 'latest')
    ..addOption(
      'dest',
      abbr: 'd',
      defaultsTo:
          'android${Platform.pathSeparator}app${Platform.pathSeparator}src${Platform.pathSeparator}main${Platform.pathSeparator}jniLibs${Platform.pathSeparator}arm64-v8a',
      help: 'Destination directory for jniLibs (default: android/app/src/main/jniLibs/arm64-v8a)',
    )
    ..addOption('github-token', defaultsTo: '')
    ..addFlag('dry-run', negatable: false, defaultsTo: false)
    ..addFlag('help', abbr: 'h', negatable: false, defaultsTo: false);

  // Preprocess args to handle empty --github-token
  final preArgs = List<String>.from(args);
  for (var i = 0; i < preArgs.length; i++) {
    if (preArgs[i] == '--github-token') {
      if (i == preArgs.length - 1 || preArgs[i + 1].startsWith('-')) {
        preArgs[i] = '--github-token=';
      }
    }
  }

  final results = parser.parse(preArgs);

  if (results['help'] as bool) {
    stdout.writeln('Usage: dart run tools/fetch_llama_server.dart [options]\n');
    stdout.writeln('Options:');
    stdout.writeln(parser.usage);
    stdout.writeln('\nExamples:');
    stdout.writeln('  # Download latest llama-server');
    stdout.writeln('  dart run tools/fetch_llama_server.dart');
    stdout.writeln('');
    stdout.writeln('  # Download specific version');
    stdout.writeln('  dart run tools/fetch_llama_server.dart --tag b9247');
    stdout.writeln('');
    stdout.writeln('  # Custom destination');
    stdout.writeln(
      '  dart run tools/fetch_llama_server.dart --dest /path/to/jniLibs/arm64-v8a',
    );
    exit(0);
  }

  final repo = results['repo'] as String;
  final tag = results['tag'] as String;
  final destDir = results['dest'] as String;
  var token = (results['github-token'] as String).trim();
  if (token.startsWith('-')) token = '';
  final dryRun = results['dry-run'] as bool;

  // Fallback to environment variable for token
  if (token.isEmpty) {
    final envTok = Platform.environment['GITHUB_TOKEN'] ?? '';
    if (envTok.isNotEmpty) {
      token = envTok;
      stdout.writeln('Using GITHUB_TOKEN from environment');
    }
  }

  stdout.writeln('=== Fetch llama-server for Android ===');
  stdout.writeln('Repo: $repo');
  stdout.writeln('Tag: $tag');
  stdout.writeln('Destination: $destDir');
  stdout.writeln('');

  if (dryRun) {
    stdout.writeln('[DRY RUN] Planned actions:');
    stdout.writeln('  1. Fetch release info from GitHub');
    stdout.writeln('  2. Download Android arm64 binary package');
    stdout.writeln('  3. Extract and rename llama-server -> $binaryName');
    stdout.writeln('  4. Install all .so files to: $destDir');
    stdout.writeln('\n[DRY RUN] Exiting');
    exit(0);
  }

  // Step 1: Fetch release information
  stdout.writeln('Step 1: Fetching release information...');
  final releaseData = await fetchRelease(repo, tag, token);
  final assets = (releaseData['assets'] as List).cast<Map<String, dynamic>>();

  stdout.writeln('Found ${assets.length} assets in release');

  // Step 2: Find Android arm64 asset
  stdout.writeln('\nStep 2: Searching for Android arm64 binary...');
  final androidAsset = findAndroidAsset(assets);

  if (androidAsset == null) {
    stderr.writeln('\nError: No Android arm64 binary found in release');
    stderr.writeln('Available assets:');
    for (final asset in assets) {
      stderr.writeln('  - ${asset['name']}');
    }
    exit(1);
  }

  final assetName = androidAsset['name'] as String;
  final assetUrl = androidAsset['url'] as String;
  stdout.writeln('Selected: $assetName');
  stdout.writeln('URL: $assetUrl');

  // Step 3: Download and extract
  stdout.writeln('\nStep 3: Downloading and extracting...');
  final tempDir = await Directory.systemTemp.createTemp('llama_server_');
  try {
    await downloadAndExtract(assetUrl, assetName, token, tempDir.path);

    // Step 4: Process and install binaries
    stdout.writeln('\nStep 4: Processing binaries...');
    await installBinaries(tempDir.path, destDir);

    stdout.writeln('\n=== Installation Complete ===');
    stdout.writeln('All llama-server binaries installed to: $destDir');
    stdout.writeln('\nInstalled files:');
    final jniDir = Directory(destDir);
    await for (final entity in jniDir.list(recursive: false)) {
      if (entity is File) {
        final size = await entity.length();
        final sizeStr = formatBytes(size);
        stdout.writeln('  ${entity.uri.pathSegments.last} ($sizeStr)');
      }
    }
  } finally {
    // Cleanup temp directory
    await tempDir.delete(recursive: true);
  }
}

/// Fetch release data from GitHub API
Future<Map<String, dynamic>> fetchRelease(
  String repo,
  String tag,
  String token,
) async {
  final apiUrl = tag == 'latest'
      ? 'https://api.github.com/repos/$repo/releases/latest'
      : 'https://api.github.com/repos/$repo/releases/tags/$tag';

  final headers = <String, String>{
    'Accept': 'application/vnd.github.v3+json',
  };
  if (token.isNotEmpty) {
    headers['Authorization'] = 'token $token';
  }

  stdout.writeln('Fetching: $apiUrl');

  final resp = await http.get(Uri.parse(apiUrl), headers: headers);

  if (resp.statusCode == 200) {
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  // If 'latest' failed, try fetching all releases
  if (tag == 'latest') {
    stdout.writeln('Failed to fetch latest, trying fallback...');
    return await fetchLatestFromAllReleases(repo, token);
  }

  throw HttpException(
    'Failed to fetch release: ${resp.statusCode}\n${resp.body}',
  );
}

/// Fallback: fetch all releases and pick the latest non-draft
Future<Map<String, dynamic>> fetchLatestFromAllReleases(
  String repo,
  String token,
) async {
  final apiUrl = 'https://api.github.com/repos/$repo/releases';
  final headers = <String, String>{
    'Accept': 'application/vnd.github.v3+json',
  };
  if (token.isNotEmpty) {
    headers['Authorization'] = 'token $token';
  }

  final resp = await http.get(Uri.parse(apiUrl), headers: headers);

  if (resp.statusCode != 200) {
    throw HttpException('Failed to fetch releases: ${resp.statusCode}');
  }

  final releases = (json.decode(resp.body) as List).cast<Map<String, dynamic>>();

  for (final release in releases) {
    if (!(release['draft'] as bool)) {
      stdout.writeln('Found latest release: ${release['tag_name']}');
      return release;
    }
  }

  throw Exception('No non-draft releases found');
}

/// Find Android arm64 asset from release assets
Map<String, dynamic>? findAndroidAsset(List<Map<String, dynamic>> assets) {
  for (final asset in assets) {
    final name = (asset['name'] as String).toLowerCase();
    // Match pattern: llama-{version}-bin-android-arm64.tar.gz
    if (name.contains('android') &&
        name.contains('arm64') &&
        (name.endsWith('.tar.gz') || name.endsWith('.tgz'))) {
      return {
        'name': asset['name'] as String,
        'url': asset['browser_download_url'] as String,
      };
    }
  }
  return null;
}

/// Download and extract archive
Future<void> downloadAndExtract(
  String assetUrl,
  String assetName,
  String token,
  String extractDir,
) async {
  stdout.writeln('Downloading from: $assetUrl');

  final headers = <String, String>{};
  if (token.isNotEmpty) {
    headers['Authorization'] = 'token $token';
  }

  final resp = await http.get(Uri.parse(assetUrl), headers: headers);

  if (resp.statusCode != 200) {
    throw HttpException('Download failed: ${resp.statusCode}');
  }

  final bytes = resp.bodyBytes;
  stdout.writeln('Downloaded: ${formatBytes(bytes.length)}');

  stdout.writeln('Extracting to: $extractDir');
  final extractDirObj = Directory(extractDir);
  await extractDirObj.create(recursive: true);

  // Extract tar.gz
  if (assetName.toLowerCase().endsWith('.tar.gz') ||
      assetName.toLowerCase().endsWith('.tgz')) {
    final gunz = GZipDecoder().decodeBytes(bytes);
    final tar = TarDecoder().decodeBytes(gunz);

    for (final file in tar.files) {
      if (file.isFile) {
        final filePath = '$extractDir/${file.name}';
        final outFile = File(filePath);
        await outFile.create(recursive: true);

        final content = file.content;
        if (content is List<int> && content.isNotEmpty) {
          await outFile.writeAsBytes(content, flush: true);
        }
      }
    }
  } else if (assetName.toLowerCase().endsWith('.zip')) {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile) {
        final filePath = '$extractDir/${file.name}';
        final outFile = File(filePath);
        await outFile.create(recursive: true);

        final content = file.content;
        if (content is List<int> && content.isNotEmpty) {
          await outFile.writeAsBytes(content, flush: true);
        }
      }
    }
  } else {
    throw Exception('Unsupported archive format: $assetName');
  }

  stdout.writeln('Extraction complete');
}

/// Process and install binaries to jniLibs
Future<void> installBinaries(String extractDir, String destDir) async {
  final srcDir = Directory(extractDir);

  // Find the extracted directory (e.g., llama-b9247/)
  Directory? llamaDir;
  await for (final entity in srcDir.list(recursive: false)) {
    if (entity is Directory) {
      llamaDir = entity;
      break;
    }
  }

  if (llamaDir == null) {
    throw Exception('No extracted directory found in: $extractDir');
  }

  stdout.writeln('Processing binaries from: ${llamaDir.path}');

  // Create destination directory
  final destDirObj = Directory(destDir);
  if (await destDirObj.exists()) {
    stdout.writeln('Cleaning existing directory: $destDir');
    await destDirObj.delete(recursive: true);
  }
  await destDirObj.create(recursive: true);

  var installedCount = 0;

  // Copy all .so files and llama-server executable
  await for (final entity in llamaDir.list(recursive: false)) {
    if (entity is File) {
      final fileName = entity.uri.pathSegments.last;

      // Skip non-binary files
      if (fileName == 'LICENSE' || fileName.endsWith('.txt')) {
        continue;
      }

      String destFileName = fileName;

      // Rename llama-server to libllama-server.so
      if (fileName == 'llama-server') {
        destFileName = binaryName;
        stdout.writeln('Renaming: $fileName -> $destFileName');
      }

      // Copy only .so files and the renamed llama-server
      if (destFileName.endsWith('.so')) {
        final destFile = File('$destDir${Platform.pathSeparator}$destFileName');
        await entity.copy(destFile.path);

        final size = await destFile.length();
        stdout.writeln(
          'Installed: $destFileName (${formatBytes(size)})',
        );
        installedCount++;
      }
    }
  }

  if (installedCount == 0) {
    throw Exception('No binaries were installed');
  }

  stdout.writeln('\nTotal files installed: $installedCount');

  // Write version info
  final versionFile = File(
    '$destDir${Platform.pathSeparator}version.txt',
  );
  await versionFile.writeAsString(
    'llama.cpp server (from llama.cpp release)\nInstalled: ${DateTime.now().toIso8601String()}\n',
    flush: true,
  );
}

/// Format bytes to human-readable string
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
