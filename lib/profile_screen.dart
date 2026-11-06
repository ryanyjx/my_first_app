import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

const Color backgroundColor = Color(0xFF121826);
const Color cardColor = Color(0xFF1E293B);
const Color blue = Color(0xFF3D7BFF);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? profileImagePath;
  String currentCurrency = '';

  @override
  void initState() {
    super.initState();
    loadProfilePicture();
    loadCurrency();
  }

  Future<void> loadProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    final savedPath = prefs.getString('profileImage_${user.uid}');

    if (savedPath != null && File(savedPath).existsSync()) {
      setState(() {
        profileImagePath = savedPath;
      });
    }
  }

  Future<void> loadCurrency() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    final currencyKey = 'currency_${user.uid}';
    final baseCurrencyKey = 'baseCurrency_${user.uid}';

    final savedCurrency = prefs.getString(currencyKey) ?? 'MYR';

    // Set MYR as the base currency for existing accounts
    // that don't have a base currency saved yet.
    if (!prefs.containsKey(baseCurrencyKey)) {
      await prefs.setString(baseCurrencyKey, 'MYR');
    }

    if (!mounted) return;

    setState(() {
      currentCurrency = savedCurrency;
    });
  }

  Future<void> changeCurrency() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final selectedCurrency = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Select Currency',
          style: TextStyle(color: Colors.white),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'MYR'),
            child: const Text('MYR - Malaysian Ringgit (RM)',
                style: TextStyle(color: Colors.white)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'SGD'),
            child: const Text('SGD - Singapore Dollar (S\$)',
                style: TextStyle(color: Colors.white)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'USD'),
            child: const Text('USD - US Dollar (\$)',
                style: TextStyle(color: Colors.white)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'GBP'),
            child: const Text('GBP - British Pound (£)',
                style: TextStyle(color: Colors.white)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'EUR'),
            child: const Text('EUR - Euro (€)',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (selectedCurrency == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'currency_${user.uid}',
      selectedCurrency,
    );

    if (!mounted) return;

    setState(() {
      currentCurrency = selectedCurrency;
    });
  }

  String getCurrencyName(String currency) {
    switch (currency) {
      case 'MYR':
        return 'Malaysian Ringgit (RM)';
      case 'SGD':
        return 'Singapore Dollar (S\$)';
      case 'USD':
        return 'US Dollar (\$)';
      case 'GBP':
        return 'British Pound (£)';
      case 'EUR':
        return 'Euro (€)';
      default:
        return currency;
    }
  }

  Future<void> uploadProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();

    final pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedImage == null) return;

    final directory = await getApplicationDocumentsDirectory();

    final savedImage = await File(pickedImage.path).copy(
      '${directory.path}/profile_${user.uid}.jpg',
    );

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'profileImage_${user.uid}',
      savedImage.path,
    );

    if (!mounted) return;

    setState(() {
      profileImagePath = savedImage.path;
    });
  }

  Future<void> deleteProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || profileImagePath == null) return;

    final imageFile = File(profileImagePath!);

    if (await imageFile.exists()) {
      await imageFile.delete();
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('profileImage_${user.uid}');

    setState(() {
      profileImagePath = null;
    });
  }

  Future<void> editUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String newUsername = user.displayName ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Change Username',
          style: TextStyle(color: Colors.white),
        ),
        content: TextFormField(
          autofocus: true,
          initialValue: user.displayName ?? '',
          onChanged: (value) {
            newUsername = value.trim();
          },
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new username',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true || newUsername.isEmpty) return;

    try {
      await user.updateDisplayName(newUsername);
      await user.reload();

      if (!mounted) return;

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update username: $e')),
      );
    }
  }

  Future<void> editEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    String newEmail = user.email!;
    String currentPassword = '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Change Email',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              autofocus: true,
              initialValue: user.email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                newEmail = value.trim();
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter new email',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true,
              onChanged: (value) {
                currentPassword = value;
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter current password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true ||
        newEmail.isEmpty ||
        newEmail == user.email ||
        currentPassword.isEmpty) {
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent. Check your new email address.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update email: $e')),
      );
    }
  }

  Future<void> logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: cardColor,
                  backgroundImage: profileImagePath != null
                      ? FileImage(File(profileImagePath!))
                      : (user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null) as ImageProvider?,
                  child: profileImagePath == null && user?.photoURL == null
                      ? const Icon(Icons.person, size: 60, color: blue)
                      : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PopupMenuButton<String>(
                        tooltip: 'Profile picture options',
                        onSelected: (value) async {
                          if (value == 'upload') {
                            await uploadProfilePicture();
                          } else if (value == 'delete') {
                            await deleteProfilePicture();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'upload',
                            child: Row(
                              children: [
                                Icon(Icons.upload, color: blue),
                                SizedBox(width: 10),
                                Text('Upload Profile Picture'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                SizedBox(width: 10),
                                Text('Delete Profile Picture'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: blue),
                          ),
                          child: const Text(
                            'Change Picture',
                            style: TextStyle(
                              color: blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ListTile(
              tileColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.person_outline, color: blue),
              title: const Text('Username'),
              subtitle: Text(user?.displayName ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: blue),
                onPressed: editUsername,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.email_outlined, color: blue),
              title: const Text('Email'),
              subtitle: Text(user?.email ?? 'Not available'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: blue),
                onPressed: editEmail,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange, color: blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Currency',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          getCurrencyName(currentCurrency),
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: blue),
                    onPressed: changeCurrency,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.lock_outline, color: blue),
              title: const Text('Password'),
              subtitle: const Text('••••••••'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: blue),
                onPressed: () {
                  // We will add the edit function here.
                },
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
