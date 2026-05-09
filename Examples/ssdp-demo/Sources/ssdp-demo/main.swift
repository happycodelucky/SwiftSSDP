//
//  main.swift
//  ssdp-demo
//
//  Live verification harness for SwiftSSDP. Run on a network with at least one UPnP
//  device (router, Apple TV, Sonos, Hue bridge, smart TV) and you should see results
//  in seconds.
//
//  Usage:
//    swift run --package-path Examples/ssdp-demo ssdp-demo search [<target>] [--timeout N]
//    swift run --package-path Examples/ssdp-demo ssdp-demo listen
//

import Foundation
import SwiftSSDP

// stdout is line-buffered by default when connected to a pipe, which hides progress
// output during long-running streams (`listen` especially). Force unbuffered output so
// every print hits the terminal / log file immediately.
setbuf(stdout, nil)

// MARK: - Argument parsing (hand-rolled, no swift-argument-parser dependency)

let args = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    Usage:
      ssdp-demo search [<target>] [--timeout <seconds>]
      ssdp-demo listen
      ssdp-demo diag
      ssdp-demo help

    Subcommands:
      search    Send M-SEARCH and print discovered devices/services.
      listen    Subscribe to NOTIFY broadcasts indefinitely (Ctrl-C to stop).
      diag      Low-level network diagnostic that bypasses SwiftSSDP and uses
                Network.framework directly. Useful for isolating whether a
                'no results' problem is the library or the network/firewall.

    Targets (defaults to ssdp:all):
      ssdp:all            Search for any device or service
      upnp:rootdevice     Search for root devices only
      <wire string>       e.g. urn:schemas-upnp-org:device:MediaServer:1
    """)
    exit(args.first == "help" ? 0 : 2)
}

guard let subcommand = args.first else { usage() }

switch subcommand {
case "search":
    let rest = Array(args.dropFirst())
    let target = parseTarget(in: rest) ?? .all
    let timeout = parseTimeout(in: rest) ?? 10
    await runSearch(target: target, timeout: timeout)

case "listen":
    await runListen()

case "diag":
    await runDiag()

case "help", "-h", "--help":
    usage()

default:
    print("Unknown subcommand: \(subcommand)\n")
    usage()
}

// MARK: - Subcommand implementations

func runSearch(target: SSDPSearchTarget, timeout: TimeInterval) async {
    let discovery = SSDPDiscovery()
    print("Searching for \(target) for up to \(Int(timeout))s …\n")

    do {
        var count = 0
        for try await response in discovery.search(for: target, timeout: timeout) {
            count += 1
            print("[\(count)] \(response.searchTarget)")
            print("    USN:      \(response.usn)")
            print("    Location: \(response.location)")
            if let server = response.server {
                print("    Server:   \(server)")
            }
            if let cc = response.cacheControl {
                print("    max-age:  \(Int(cc))s")
            }
            print("")
        }
        print("Search complete — \(count) result(s).")
    } catch {
        print("Search failed: \(error)")
        exit(1)
    }
}

func runListen() async {
    let discovery = SSDPDiscovery()
    print("Listening for SSDP NOTIFY broadcasts on \(SSDPDiscovery.ssdpHost):\(SSDPDiscovery.ssdpPort) …")
    print("(Press Ctrl-C to stop.)\n")

    do {
        for try await notification in discovery.notifications() {
            switch notification {
            case .alive(let ad):
                print("→  ALIVE   \(ad.notificationTarget)")
                print("           USN: \(ad.usn)")
                if let loc = ad.location {
                    print("           at  \(loc)")
                }
            case .byebye(let ad):
                print("←  BYEBYE  \(ad.notificationTarget)")
                print("           USN: \(ad.usn)")
            case .update(let ad):
                print("⟳  UPDATE  \(ad.notificationTarget)  bootID=\(ad.bootID ?? -1)→\(ad.nextBootID ?? -1)")
                print("           USN: \(ad.usn)")
            }
            print("")
        }
    } catch let error as SSDPError {
        switch error {
        case .multicastEntitlementMissing:
            print("ERROR: This app is missing the com.apple.developer.networking.multicast entitlement.")
            print("On iOS / iPadOS / tvOS, joining the SSDP multicast group requires that entitlement.")
            print("Apply for it at: https://developer.apple.com/contact/request/networking-multicast")
            print("(macOS does not require it — running this demo on macOS should just work.)")
        default:
            print("ERROR: \(error)")
        }
        exit(1)
    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
}

// MARK: - Argument helpers

func parseTarget(in args: [String]) -> SSDPSearchTarget? {
    // First non-flag positional is the target.
    var iter = args.makeIterator()
    while let arg = iter.next() {
        if arg.hasPrefix("--") {
            // Skip the value of two-token flags.
            _ = iter.next()
            continue
        }
        return SSDPSearchTarget(rawValue: arg)
    }
    return nil
}

func parseTimeout(in args: [String]) -> TimeInterval? {
    guard let i = args.firstIndex(of: "--timeout"), i + 1 < args.count else { return nil }
    return Double(args[i + 1])
}
