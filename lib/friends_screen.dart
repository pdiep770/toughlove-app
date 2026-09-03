import 'package:flutter/material.dart';
import 'friend_service.dart';
import 'user_profile_service.dart';
import 'chat_screen.dart';
import 'streak_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _myFriendCode;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _friends = [];
  Map<String, int> _streaks = {};
  bool _loading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final profile = await UserProfileService().getProfile();
    final requests = await FriendService().getPendingRequests();
    final friends = await FriendService().getFriends();

    final streakService = StreakService();
    final streakEntries = await Future.wait(friends.map((f) async {
      final uid = f['uid'] as String;
      return MapEntry(uid, await streakService.getStreakWith(uid));
    }));

    if (mounted) {
      setState(() {
        _myFriendCode = profile?['friendCode'];
        _pendingRequests = requests;
        _friends = friends;
        _streaks = Map.fromEntries(streakEntries);
        _loading = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final result = await FriendService().sendFriendRequest(code);
    setState(() => _statusMessage = result);
    _codeController.clear();
    _loadData();
  }

  Future<void> _accept(String requestId, String fromUid) async {
    await FriendService().acceptRequest(requestId, fromUid);
    _loadData();
  }

  Future<void> _decline(String requestId) async {
    await FriendService().declineRequest(requestId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_myFriendCode != null) ...[
                    const Text('Your friend code'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _myFriendCode!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text('Add a friend'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(hintText: 'Enter their friend code'),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _sendRequest, child: const Text('Add')),
                    ],
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_statusMessage!),
                  ],
                  const SizedBox(height: 24),
                  if (_pendingRequests.isNotEmpty) ...[
                    Text('Pending requests', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._pendingRequests.map((req) => Card(
                          child: ListTile(
                            title: Text(req['fromDisplayName'] ?? 'Someone'),
                            subtitle: const Text('wants to be friends'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _accept(req['requestId'], req['fromUid']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _decline(req['requestId']),
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],
                  Text('Your friends (${_friends.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_friends.isEmpty)
                    const Text('No friends yet — share your code above!')
                  else
                    ..._friends.map((f) {
                      final streak = _streaks[f['uid']] ?? 0;
                      return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(f['displayName']),
                            subtitle: streak > 0 ? Text('🔥 $streak day streak') : null,
                            trailing: const Icon(Icons.chat_bubble_outline),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(friendUid: f['uid'], friendName: f['displayName']),
                                ),
                              );
                            },
                          ),
                        );
                    }),
                ],
              ),
            ),
    );
  }
}