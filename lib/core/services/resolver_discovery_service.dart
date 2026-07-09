import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

class ResolverDiscoveryService {
  const ResolverDiscoveryService();

  static const serviceType = '_musehub-resolver._tcp.local';

  Future<String?> discover({
    Duration browseTimeout = const Duration(seconds: 4),
    Duration recordTimeout = const Duration(seconds: 2),
  }) async {
    if (kIsWeb) return null;

    final client = MDnsClient();
    try {
      await client.start();
      final ptrRecords = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType),
          )
          .toList()
          .timeout(
            browseTimeout,
            onTimeout: () => const <PtrResourceRecord>[],
          );

      for (final ptr in ptrRecords) {
        final srvRecords = await client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .toList()
            .timeout(
              recordTimeout,
              onTimeout: () => const <SrvResourceRecord>[],
            );

        for (final srv in srvRecords) {
          final ipRecords = await client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .toList()
              .timeout(
                recordTimeout,
                onTimeout: () => const <IPAddressResourceRecord>[],
              );
          if (ipRecords.isEmpty) continue;
          return 'http://${ipRecords.first.address.address}:${srv.port}';
        }
      }
    } on Object {
      return null;
    } finally {
      client.stop();
    }

    return null;
  }
}
