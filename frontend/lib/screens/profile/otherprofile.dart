import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/api_client.dart';
import '../../models/user_model.dart';

class OtherUserProfilePage extends StatefulWidget {
  final int userId;

  const OtherUserProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  late Future<Map<String, dynamic>> _userFuture;
  final ApiClient _apiClient = ApiClient(); // ✅ Initialize your API client

  @override
  void initState() {
    super.initState();
    _userFuture = fetchUser(widget.userId);
  }

  Future<Map<String, dynamic>> fetchUser(int userId) async {
    try {
      final response = await _apiClient.get('/users/$userId');
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final user = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    child: Text(user['name'][0]),
                  ),
                  const SizedBox(height: 16),
                  Text(user['name'], style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('@${user['username']}'),
                  const SizedBox(height: 8),
                  Text(user['gender'] == true ? 'Male' : 'Female'),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}