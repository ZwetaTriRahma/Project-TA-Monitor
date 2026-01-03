import 'package:flutter/material.dart';

class ProfessionalScreen extends StatelessWidget {
  const ProfessionalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          IconButton(
            icon: const CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d'),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 16),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d'),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Welcome, User!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Here is a summary of your tasks.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildActionCard(Icons.add, 'Add Task'),
        _buildActionCard(Icons.list, 'View Tasks'),
        _buildActionCard(Icons.person_add, 'Add Student'),
        _buildActionCard(Icons.bar_chart, 'View Progress'),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String label) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Task "Implementasi UI" completed'),
                subtitle: Text('2 hours ago'),
              ),
              ListTile(
                leading: Icon(Icons.add_comment, color: Colors.orange),
                title: Text('New comment on "Perancangan Database"'),
                subtitle: Text('5 hours ago'),
              ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.blue),
                title: Text('New student "Budi" added'),
                subtitle: Text('1 day ago'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
