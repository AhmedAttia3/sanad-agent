import 'dart:io';

void main() {
  print('=== Starting Wiki Archiving and Sequential Reorganization ===\n');

  final docsDir = Directory('docs');
  final dotDocsDir = Directory('.docs');
  final sanadagentPlansDir = Directory('sanadagent-local/docs/plans');

  final draftsDest = Directory('docs/archive/drafts');
  final legacyDest = Directory('docs/archive/legacy');
  final plansDest = Directory('docs/archive/plans');
  final localPlansDest = Directory('docs/archive/sanadagent-local-plans');

  // 1. Ensure target directories exist
  draftsDest.createSync(recursive: true);
  legacyDest.createSync(recursive: true);
  plansDest.createSync(recursive: true);
  localPlansDest.createSync(recursive: true);

  // Helper helper to get all markdown/text files in a directory recursively
  List<File> getFiles(Directory dir, {bool recursive = true}) {
    if (!dir.existsSync()) return [];
    final files = <File>[];
    for (final entity in dir.listSync(recursive: recursive)) {
      if (entity is File) {
        final path = entity.path.toLowerCase();
        if (path.endsWith('.md') || path.endsWith('.txt')) {
          // Skip active documentation files in root docs
          final name = entity.uri.pathSegments.last;
          if (name == 'llms.txt' || name == 'llms-full.txt' || name == 'agent_workflow.md') {
            continue;
          }
          // Skip files inside already archived directories to prevent double archiving
          if (entity.path.contains('docs/archive') || entity.path.contains('docs\\archive')) {
            continue;
          }
          files.add(entity);
        }
      }
    }
    return files;
  }

  // Helper to sort files by modification/creation date (oldest to newest)
  void sortFilesByDate(List<File> files) {
    files.sort((a, b) {
      final aTime = a.lastModifiedSync().millisecondsSinceEpoch;
      final bTime = b.lastModifiedSync().millisecondsSinceEpoch;
      if (aTime != bTime) {
        return aTime.compareTo(bTime);
      }
      return a.path.compareTo(b.path); // Alphabetical fallback for parity
    });
  }

  // Helper to rename and move files sequentially
  void archiveAndRename(List<File> files, Directory destDir) {
    sortFilesByDate(files);
    print('Sorting and archiving ${files.length} files to ${destDir.path}:');
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final originalName = file.uri.pathSegments.last;
      
      // Clean previous numbering if any to avoid double prefixing
      var cleanName = originalName;
      final numberPrefixRegex = RegExp(r'^\d+[-_]');
      if (numberPrefixRegex.hasMatch(cleanName)) {
        cleanName = cleanName.replaceFirst(numberPrefixRegex, '');
      }

      final indexStr = i.toString().padLeft(2, '0');
      final newName = '$indexStr-$cleanName';
      final newPath = '${destDir.path}${Platform.pathSeparator}$newName';
      
      print('  [${file.path}] -> [$newPath]');
      file.renameSync(newPath);
    }
  }

  // 2. Archive .docs -> docs/archive/drafts/
  print('--- Processing Hidden .docs Directory ---');
  final dotDocsFiles = getFiles(dotDocsDir, recursive: true);
  if (dotDocsFiles.isNotEmpty) {
    archiveAndRename(dotDocsFiles, draftsDest);
    // Clean up .docs directory if it's empty
    try {
      if (dotDocsDir.listSync(recursive: true).isEmpty) {
        dotDocsDir.deleteSync(recursive: true);
        print('Deleted empty hidden .docs directory.');
      } else {
        // If there are subdirectories (like 5-2026) that are empty, clean them
        for (final entity in dotDocsDir.listSync(recursive: true)) {
          if (entity is Directory && entity.listSync().isEmpty) {
            entity.deleteSync();
          }
        }
        if (dotDocsDir.listSync().isEmpty) {
          dotDocsDir.deleteSync();
          print('Deleted empty hidden .docs directory.');
        }
      }
    } catch (e) {
      print('Warning: could not clean .docs directory: $e');
    }
  } else {
    print('No files found in .docs directory.');
  }
  print('');

  // 3. Archive docs/plans/ -> docs/archive/plans/
  print('--- Processing docs/plans/ Directory ---');
  final plansDir = Directory('docs/plans');
  if (plansDir.existsSync()) {
    final plansFiles = getFiles(plansDir, recursive: true);
    if (plansFiles.isNotEmpty) {
      archiveAndRename(plansFiles, plansDest);
      // Clean up empty directories in docs/plans
      try {
        final implementedDir = Directory('docs/plans/implemented');
        if (implementedDir.existsSync() && implementedDir.listSync().isEmpty) {
          implementedDir.deleteSync();
        }
        if (plansDir.listSync().isEmpty) {
          plansDir.deleteSync();
          print('Deleted empty docs/plans directory.');
        }
      } catch (e) {
        print('Warning: could not clean plans directories: $e');
      }
    } else {
      print('No plans found in docs/plans/.');
    }
  }
  print('');

  // 4. Archive old files in docs/ (excluding tasks, llms, agent_workflow) -> docs/archive/legacy/
  print('--- Processing legacy root docs/ files ---');
  final rootDocsFiles = getFiles(docsDir, recursive: false);
  if (rootDocsFiles.isNotEmpty) {
    archiveAndRename(rootDocsFiles, legacyDest);
  } else {
    print('No legacy root docs found.');
  }
  print('');

  // 5. Move sanadagent-local/docs/plans -> docs/archive/sanadagent-local-plans/
  print('--- Processing sanadagent-local/docs/plans ---');
  if (sanadagentPlansDir.existsSync()) {
    final localFiles = getFiles(sanadagentPlansDir, recursive: false);
    if (localFiles.isNotEmpty) {
      // They are already numbered 00 to 17. Let's just move them directly to stay consistent
      print('Moving ${localFiles.length} already-numbered plans to ${localPlansDest.path}:');
      for (final file in localFiles) {
        final newPath = '${localPlansDest.path}${Platform.pathSeparator}${file.uri.pathSegments.last}';
        print('  [${file.path}] -> [$newPath]');
        file.renameSync(newPath);
      }
      // Clean up sanadagent-local/docs/plans
      try {
        if (sanadagentPlansDir.listSync().isEmpty) {
          sanadagentPlansDir.deleteSync();
          final localDocsDir = Directory('sanadagent-local/docs');
          if (localDocsDir.listSync().isEmpty) {
            localDocsDir.deleteSync();
            print('Deleted empty sanadagent-local/docs directory.');
          }
        }
      } catch (e) {
        print('Warning: could not clean sanadagent-local directories: $e');
      }
    } else {
      print('No plans found in sanadagent-local/docs/plans.');
    }
  }
  print('');

  print('=== Archiving and Reorganization Completed Successfully! ===');
}
