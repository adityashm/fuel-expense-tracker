import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/user_provider.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('select_user')),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No users yet. Add your first user!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUserDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(localizations.translate('add_user')),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: userProvider.users.length + 1,
            itemBuilder: (context, index) {
              if (index == userProvider.users.length) {
                // Add user button
                if (userProvider.users.length < AppConstants.maxUsers) {
                  return _buildAddUserCard(context);
                }
                return const SizedBox.shrink();
              }

              final user = userProvider.users[index];
              return _buildUserCard(context, user, userProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    User user,
    UserProvider userProvider,
  ) {
    return Card(
      child: InkWell(
        onTap: () {
          userProvider.setCurrentUser(user);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: user.profilePicturePath != null
                  ? FileImage(File(user.profilePicturePath!))
                  : null,
              child: user.profilePicturePath == null
                  ? Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user.name,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddUserCard(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Card(
      child: InkWell(
        onTap: () => _showAddUserDialog(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              localizations.translate('add_user'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final nameController = TextEditingController();
    String? imagePath;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(localizations.translate('add_user')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      imagePath = image.path;
                    });
                  }
                },
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      imagePath != null ? FileImage(File(imagePath!)) : null,
                  child: imagePath == null
                      ? const Icon(Icons.camera_alt, size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: localizations.translate('name'),
                  border: const OutlineInputBorder(),
                  hintText: 'Enter your name',
                ),
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (name.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name must be at least 2 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                await userProvider.createUser(name, imagePath);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(localizations.translate('save')),
            ),
          ],
        ),
      ),
    );
  }
}
