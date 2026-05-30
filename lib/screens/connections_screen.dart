import 'package:flutter/material.dart';
import '../core/mihomo_api.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  List<Map<String, dynamic>> _connections = [];
  bool _isLoading = true;
  String _error = '';

  // TODO: Initialize MihomoApi instance here
  late MihomoApi _api;

  @override
  void initState() {
    super.initState();
    // _api = MihomoApi(...); // Initialize with current port/secret
    _fetchConnections();
  }

  Future<void> _fetchConnections() async {
    setState(() => _isLoading = true);
    try {
      // final response = await _api.getConnections();
      // setState(() {
      //   _connections = response['connections'] ?? [];
      //   _isLoading = false;
      // });
      
      // Mock data for now
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _connections = [
          {
            'id': '12345',
            'metadata': {'host': 'www.google.com', 'destinationIP': '142.250.1.1'},
            'rule': 'GEOSITE,google',
            'chains': ['🚀 节点选择', 'US Node'],
            'upload': 1234,
            'download': 56789,
            'start': DateTime.now().toIso8601String(),
          }
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load connections: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活动连接'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConnections,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: '断开所有连接',
            onPressed: () {
              // _api.closeAllConnections();
              _fetchConnections();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : ListView.builder(
                  itemCount: _connections.length,
                  itemBuilder: (context, index) {
                    final conn = _connections[index];
                    final meta = conn['metadata'] as Map?;
                    final chains = List<String>.from(conn['chains'] ?? []);
                    
                    return ListTile(
                      leading: Icon(Icons.device_hub, color: Colors.blue),
                      title: Text(meta?['host'] ?? meta?['destinationIP'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${conn['rule']}', style: TextStyle(color: Colors.grey)),
                          Text(chains.join(' -> '), style: TextStyle(color: Colors.green)),
                        ],
                      ),
                      trailing: Text(
                        '${((conn['upload'] as int) + (conn['download'] as int)) ~/ 1024} KB',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        // _api.closeConnection(conn['id']);
                        _fetchConnections();
                      },
                    );
                  },
                ),
    );
  }
}
