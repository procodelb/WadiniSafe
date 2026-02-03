import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'approvals_tab.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Approvals'),
              Tab(text: 'Live Map'),
              Tab(text: 'Pricing'),
              Tab(text: 'Stands'),
              Tab(text: 'Reports'),
              Tab(text: 'Users'),
              Tab(text: 'Chats'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ApprovalsTab(),
            Center(child: Text('Live Map (Coming Soon)')),
            Center(child: Text('Pricing (Coming Soon)')),
            Center(child: Text('Stands (Coming Soon)')),
            Center(child: Text('Reports (Coming Soon)')),
            Center(child: Text('Users (Coming Soon)')),
            Center(child: Text('Chats (Coming Soon)')),
          ],
        ),
      ),
    );
  }
}
