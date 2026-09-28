import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/certificate_project.dart';

class StorageService {
  StorageService(this._preferences, {this._documentsDirectory});
  static const _projectsKey = 'certisend.projects';
  final SharedPreferences _preferences;
  final Directory? _documentsDirectory;

  Future<List<CertificateProject>> loadProjects() async {
    final encoded = _preferences.getString(_projectsKey);
    if (encoded == null || encoded.isEmpty) return [];
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded.map((item) => CertificateProject.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> saveProjects(List<CertificateProject> projects) async {
    final encoded = jsonEncode(projects.map((project) => project.toJson()).toList());
    if (!await _preferences.setString(_projectsKey, encoded)) throw const FileSystemException('Unable to save project data.');
  }

  Future<Directory> get documentsDirectory async => _documentsDirectory ?? await getApplicationDocumentsDirectory();

  Future<String> storeFile(String sourcePath, String folder, String fileName) async {
    final root = await documentsDirectory;
    final directory = Directory('${root.path}${Platform.pathSeparator}certisend${Platform.pathSeparator}$folder');
    await directory.create(recursive: true);
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final destination = File('${directory.path}${Platform.pathSeparator}$safeName');
    return (await File(sourcePath).copy(destination.path)).path;
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}