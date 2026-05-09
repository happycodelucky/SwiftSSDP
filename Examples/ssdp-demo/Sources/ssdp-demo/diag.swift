//
//  diag.swift
//  ssdp-demo
//
//  Low-level network diagnostic: bypasses SwiftSSDP entirely and uses Network.framework
//  directly. If `ssdp-demo diag` finds devices but `ssdp-demo search` does not, the bug
//  is in SwiftSSDP. If neither finds devices, the bug is in your network or entitlements.
//

import Foundation
import Network

func runDiag() async {
    print("Diagnostic: bypassing SwiftSSDP, using NWConnectionGroup directly.\n")

    let host = NWEndpoint.Host("239.255.255.250")
    let port = NWEndpoint.Port(rawValue: 1900)!

    do {
        let multicast = try NWMulticastGroup(for: [.hostPort(host: host, port: port)])
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        let group = NWConnectionGroup(with: multicast, using: params)

        let receivedCount = Counter()

        group.setReceiveHandler(maximumMessageSize: 65_507, rejectOversizedMessages: true)
        { message, content, _ in
            guard let data = content, !data.isEmpty else { return }
            let source = message.remoteEndpoint?.debugDescription ?? "unknown"
            let preview = String(data: data.prefix(120), encoding: .utf8) ?? "<binary>"
            let firstLine = preview.split(whereSeparator: \.isNewline).first ?? ""
            Task { await receivedCount.bump() }
            print("[recv] from \(source): \(firstLine)")
        }

        group.stateUpdateHandler = { state in
            print("[state] group state: \(state)")
        }

        let queue = DispatchQueue(label: "diag", qos: .utility)
        group.start(queue: queue)

        // Wait briefly for ready.
        try await Task.sleep(for: .milliseconds(500))

        // Send an M-SEARCH for ssdp:all.
        let msearch = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            MX: 2\r
            ST: ssdp:all\r
            \r

            """
        let payload = Data(msearch.utf8)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)

        print("[send] M-SEARCH ssdp:all → 239.255.255.250:1900\n")
        group.send(content: payload, to: endpoint, completion: { error in
            if let error {
                print("[send] failed: \(error)")
            } else {
                print("[send] sent successfully")
            }
        })

        // Listen for 8 seconds.
        try await Task.sleep(for: .seconds(8))

        print("\n--- diag complete: received \(await receivedCount.value) datagrams ---")
        if await receivedCount.value == 0 {
            print("""

                If 0 datagrams were received, possible causes:
                  1. No SSDP-emitting devices are reachable on this LAN.
                  2. macOS firewall is blocking inbound UDP/1900.
                  3. The Wi-Fi network is using AP isolation / client isolation.
                  4. Devices are on a different VLAN with no multicast forwarding.

                Try in another terminal:
                  sudo tcpdump -i en0 -A -n 'host 239.255.255.250 or (udp and port 1900)'

                If tcpdump shows packets but this program shows 0, the bug is in
                Network.framework usage.
                """)
        }
        group.cancel()

    } catch {
        print("Diag failed at setup: \(error)")
    }
}

actor Counter {
    private(set) var value = 0
    func bump() { value += 1 }
}
