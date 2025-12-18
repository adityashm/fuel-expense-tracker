import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StorageTestScreen extends StatefulWidget {
  const StorageTestScreen({super.key});

  @override
  State<StorageTestScreen> createState() => _StorageTestScreenState();
}

class _StorageTestScreenState extends State<StorageTestScreen> {
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _statusMessage;
  String? _downloadUrl;
  final List<String> _testResults = [];

  @override
  void initState() {
    super.initState();
    _runBasicTests();
  }

  Future<void> _runBasicTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    // Test 1: Check Firebase Auth
    try {
      final user = _auth.currentUser;
      if (user == null) {
        await _auth.signInAnonymously();
        _addResult('✅ Signed in anonymously: ${_auth.currentUser?.uid}');
      } else {
        _addResult('✅ Already signed in: ${user.uid}');
      }
    } catch (e) {
      _addResult('❌ Auth test failed: $e');
      setState(() => _isLoading = false);
      return;
    }

    // Test 2: Check Storage bucket
    try {
      final bucket = _storage.ref().bucket;
      _addResult('✅ Storage bucket: $bucket');
    } catch (e) {
      _addResult('❌ Storage bucket error: $e');
    }

    // Test 3: Try to write a test file
    try {
      final testRef = _storage
          .ref()
          .child('test/test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await testRef.putString('Hello from Flutter!');
      _addResult('✅ Upload test file successful');

      // Test 4: Get download URL
      final url = await testRef.getDownloadURL();
      _addResult('✅ Download URL retrieved');
      setState(() => _downloadUrl = url);

      // Test 5: Delete test file
      await testRef.delete();
      _addResult('✅ Delete test file successful');
    } catch (e) {
      _addResult('❌ Storage operation failed: $e');
    }

    setState(() => _isLoading = false);
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add(result);
    });
  }

  Future<void> _testImageUpload() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Selecting image...';
    });

    try {
      // Pick image
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() {
          _statusMessage = 'No image selected';
          _isLoading = false;
        });
        return;
      }

      setState(() => _statusMessage = 'Uploading image...');

      // Upload to Storage
      final userId = _auth.currentUser?.uid ?? 'test_user';
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
          _storage.ref().child('users/$userId/receipts/$fileName');

      final file = File(pickedFile.path);
      final uploadTask = storageRef.putFile(file);

      // Monitor progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        setState(() {
          _statusMessage = 'Uploading: ${progress.toStringAsFixed(1)}%';
        });
      });

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _statusMessage = 'Upload successful!';
        _downloadUrl = downloadUrl;
        _isLoading = false;
      });

      _addResult('✅ Image uploaded: $fileName');
      _addResult('✅ Download URL: $downloadUrl');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Upload failed: $e';
        _isLoading = false;
      });

      _addResult('❌ Image upload failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkStorageRules() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking Storage rules...';
    });

    try {
      final userId = _auth.currentUser?.uid ?? 'test_user';

      // Try to read from user's own path
      final userRef = _storage.ref().child('users/$userId/test.txt');
      try {
        await userRef.getDownloadURL();
        _addResult('✅ Can read from user path (or file exists)');
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
          _addResult('✅ User path accessible (file not found is OK)');
        } else {
          _addResult('❌ Cannot read user path: $e');
        }
      }

      // Try to read from another user's path (should fail)
      final otherUserRef = _storage.ref().child('users/other_user_id/test.txt');
      try {
        await otherUserRef.getDownloadURL();
        _addResult(
          '⚠️ WARNING: Can read other users\' data! Update security rules!',
        );
      } catch (e) {
        if (e.toString().contains('unauthorized') ||
            e.toString().contains('permission-denied')) {
          _addResult(
            '✅ Security rules working: Cannot access other users\' data',
          );
        } else {
          _addResult('ℹ️ Other user path test: $e');
        }
      }

      setState(() {
        _statusMessage = 'Rules check complete';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Rules check failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Storage Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runBasicTests,
            tooltip: 'Re-run tests',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _isLoading ? Colors.blue.shade50 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isLoading) const CircularProgressIndicator(),
                    if (_isLoading) const SizedBox(height: 16),
                    if (_statusMessage != null)
                      Text(
                        _statusMessage!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testImageUpload,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Test Image Upload'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkStorageRules,
              icon: const Icon(Icons.security),
              label: const Text('Check Security Rules'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runBasicTests,
              icon: const Icon(Icons.refresh),
              label: const Text('Run Basic Tests'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 24),

            // Download URL
            if (_downloadUrl != null) ...[
              const Text(
                'Last Upload URL:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _downloadUrl!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Test Results
            const Text(
              'Test Results:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (_testResults.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No results yet. Tests will run automatically on load.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_testResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _testResults.map((result) {
                    final isSuccess = result.startsWith('✅');
                    final isError = result.startsWith('❌');
                    final isWarning = result.startsWith('⚠️');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isSuccess
                                ? Icons.check_circle
                                : isError
                                    ? Icons.error
                                    : isWarning
                                        ? Icons.warning
                                        : Icons.info,
                            size: 20,
                            color: isSuccess
                                ? Colors.green
                                : isError
                                    ? Colors.red
                                    : isWarning
                                        ? Colors.orange
                                        : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result,
                              style: TextStyle(
                                color: isError
                                    ? Colors.red.shade700
                                    : Colors.black87,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 24),

            // Troubleshooting Tips
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Troubleshooting Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTip(
                      'If all tests fail, check Firebase Console → Storage is enabled',
                    ),
                    _buildTip(
                      'If upload fails with "unauthorized", check Storage security rules',
                    ),
                    _buildTip(
                      'If "object-not-found", file doesn\'t exist (this is OK for tests)',
                    ),
                    _buildTip(
                      'Check STORAGE_TROUBLESHOOTING.md for detailed solutions',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
