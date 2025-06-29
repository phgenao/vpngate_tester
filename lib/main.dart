import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: VPNGatePingTester(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Server {
  final String ip;
  final String country;
  final String port;
  final int? ping;

  Server({required this.ip, required this.country, required this.port, this.ping});
}

class VPNGatePingTester extends StatefulWidget {
  const VPNGatePingTester({super.key});

  @override
  State<VPNGatePingTester> createState() => _VPNGatePingTesterState();
}

class _VPNGatePingTesterState extends State<VPNGatePingTester> {
  List<Server> servers = [];
  bool isLoading = false;

  Future<void> fetchAndTestServers() async {
    setState(() => isLoading = true);

    const url = 'http://www.vpngate.net/api/iphone/';
    final response = await http.get(Uri.parse(url));
    final lines = const LineSplitter().convert(response.body);

    List<Server> parsedServers = [];

    for (var line in lines) {
      if (line.startsWith('*') || line.startsWith('#') || line.contains('HostName')) continue;
      final row = line.split(',');
      if (row.length < 15) continue;
      final ip = row[1];
      final country = row[6];
      final port = row[2];
      parsedServers.add(Server(ip: ip, country: country, port: port));
    }

    List<Server> tested = [];

    for (var server in parsedServers.take(30)) {
      final ping = await pingIP(server.ip);
      if (ping != null) {
        tested.add(Server(
          ip: server.ip,
          country: server.country,
          port: server.port,
          ping: ping,
        ));
      }
    }

    tested.sort((a, b) => a.ping!.compareTo(b.ping!));
    setState(() {
      servers = tested;
      isLoading = false;
    });
  }

  Future<int?> pingIP(String ip) async {
    try {
      final result = await Process.run('ping', ['-c', '1', ip]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final match = RegExp(r'time=([0-9.]+) ms').firstMatch(output);
        if (match != null) {
          return double.parse(match.group(1)!).round();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Gate Ping Tester'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : fetchAndTestServers,
              child: const Text('Test Servers'),
            ),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: servers.length,
                      itemBuilder: (context, index) {
                        final s = servers[index];
                        return Card(
                          child: ListTile(
                            title: Text('${s.country}'),
                            subtitle: Text('${s.ip}:${s.port}'),
                            trailing: Text('${s.ping} ms'),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}