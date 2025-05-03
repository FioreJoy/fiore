import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../models/user_model.dart';
import '../profile/otherprofile.dart';

class CommunityMembersPage extends StatefulWidget {
  final int communityId;

  const CommunityMembersPage({Key? key, required this.communityId}) : super(key: key);

  @override
  State<CommunityMembersPage> createState() => _CommunityMembersPageState();
}

class _CommunityMembersPageState extends State<CommunityMembersPage> {
  late Future<List<UserModel>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _fetchCommunityMembers();
  }

  Future<List<UserModel>> _fetchCommunityMembers() async {
  try {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? token = authProvider.token;

    if (token == null) {
      throw Exception('User not authenticated');
    }

    final apiClient = ApiClient();
    final response = await apiClient.get(
      '/users/community/${widget.communityId}/members',
      token: token,
    );

    if (response is List) {
      return response.map((e) => UserModel.fromJson(e)).toList();
    } else {
      throw Exception('Invalid response format');
    }
  } catch (e) {
    throw Exception('Failed to load community members: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Members')),
      body: FutureBuilder<List<UserModel>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final members = snapshot.data!;
            return ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final user = members[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text('@${user.username}'),
                  leading: CircleAvatar(child: Text(user.name[0])),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherUserProfilePage(userId: user.id),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}