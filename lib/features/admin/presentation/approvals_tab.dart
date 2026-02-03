import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/app_user.dart';
import 'admin_controller.dart';
import 'user_details_page.dart';

class ApprovalsTab extends ConsumerWidget {
  const ApprovalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingDriversAsync = ref.watch(pendingDriversProvider);
    final pendingClientsAsync = ref.watch(pendingClientsProvider);
    final adminControllerState = ref.watch(adminControllerProvider);

    // Show error snackbar if action failed
    ref.listen(adminControllerProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}')),
        );
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (adminControllerState.isLoading) const LinearProgressIndicator(),
          _buildSectionHeader('Pending Drivers'),
          pendingDriversAsync.when(
            data: (drivers) => drivers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No pending drivers.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: drivers.length,
                    itemBuilder: (context, index) {
                      return _UserApprovalTile(user: drivers[index]);
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error loading drivers: $err'),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Pending Clients'),
          pendingClientsAsync.when(
            data: (clients) => clients.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No pending clients.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      return _UserApprovalTile(user: clients[index]);
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error loading clients: $err'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _UserApprovalTile extends ConsumerWidget {
  final AppUser user;

  const _UserApprovalTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserDetailsPage(
                uid: user.uid,
                role: user.role,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child:
                      user.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user.displayName ?? 'Unknown Name'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone: ${user.phoneNumber ?? "N/A"}'),
                    Text('UID: ${user.uid}',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Details'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => UserDetailsPage(
                            uid: user.uid,
                            role: user.role,
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      ref
                          .read(adminControllerProvider.notifier)
                          .approveUser(user.uid, user.role);
                    },
                    tooltip: 'Approve',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      ref
                          .read(adminControllerProvider.notifier)
                          .rejectUser(user.uid, user.role);
                    },
                    tooltip: 'Reject',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
