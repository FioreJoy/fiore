import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  @override
  _CommunitiesScreenState createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  String searchQuery = '';
  final List<Color> cardColors = [
    Colors.orange.shade300,
    Colors.green.shade300,
    Colors.red.shade300,
    Colors.blue.shade300,
    Colors.purple.shade300,
  ];

  void _updateSearchQuery(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
    });
  }

  Future<void> _navigateToCreateCommunity(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to create a community.')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateCommunityScreen()),
    ).then((_) {
      setState(() {}); // Refresh communities after returning
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: _updateSearchQuery,
              decoration: InputDecoration(
                hintText: "Search for Communities...",
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),

          // Scrollable Categories with Icons
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryIcon(Icons.sports_soccer, "Sports"),
                _buildCategoryIcon(Icons.music_note, "Music"),
                _buildCategoryIcon(Icons.code, "Tech"),
                _buildCategoryIcon(Icons.palette, "Art"),
                _buildCategoryIcon(Icons.fitness_center, "Fitness"),
                _buildCategoryIcon(Icons.movie, "Movies"),
              ],
            ),
          ),

          // Community List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: FutureBuilder<List<dynamic>>(
                future: apiService.fetchCommunities(authProvider.token),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final communities = snapshot.data!
                      .where((comm) =>
                          comm['name'].toString().toLowerCase().contains(searchQuery))
                      .toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: communities.length,
                    itemBuilder: (context, index) {
                      final comm = communities[index];
                      return _buildCommunityCard(comm, index % cardColors.length);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateCommunity(context),
        child: const Icon(Icons.add),
        tooltip: "Create Community",
      ),
    );
  }

  // Widget for category icons
  Widget _buildCategoryIcon(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey.shade800,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // Widget for community card
  Widget _buildCommunityCard(dynamic comm, int colorIndex) {
    return Card(
      color: cardColors[colorIndex], // Assign color dynamically
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Community Name & Members Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  comm['name'] ?? 'No Name',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  "${comm['members'] ?? 0} members",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Online Members
            Row(
              children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                const SizedBox(width: 5),
                Text(
                  "${comm['online_members'] ?? 0} Online",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              comm['description'] ?? 'No Description',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),

            // Comments like Mutual Friends
            if (comm['mutual_friends'] != null) ...[
              Row(
                children: [
                  Icon(Icons.people, color: Colors.white70, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    "${comm['mutual_friends']} mutual friends",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}