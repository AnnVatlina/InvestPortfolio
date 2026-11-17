//
//  StoreRecovery.swift
//  InvestPortfolio
//
//  What to do when the SwiftData store can't be opened. The store is never deleted:
//  it is moved aside as a timestamped backup, and the user is told about it.
//

import Foundation

enum StoreRecovery {
    /// UserDefaults key holding a pending notice for the user, cleared once shown.
    static let noticeKey = "App_StoreRecoveryNotice"

    /// Notice kinds, stored as raw strings in UserDefaults.
    enum Notice: Equatable {
        /// The old store was moved to a backup file with this name; the app started empty.
        case backedUp(fileName: String)
        /// The store couldn't be opened or moved; the app runs in memory and saves nothing.
        case unavailable

        var rawValue: String {
            switch self {
            case .backedUp(let name): return "backup:\(name)"
            case .unavailable:        return "unavailable"
            }
        }

        init?(rawValue: String) {
            if rawValue == "unavailable" {
                self = .unavailable
            } else if rawValue.hasPrefix("backup:") {
                self = .backedUp(fileName: String(rawValue.dropFirst("backup:".count)))
            } else {
                return nil
            }
        }
    }

    // SQLite sidecar files live next to the main file, named with a "-" suffix.
    private static let suffixes = ["", "-shm", "-wal"]

    /// Moves the store and its SQLite sidecar files to `<name>.backup-<timestamp>`.
    /// Returns the new main-file URL, or `nil` if there was no store file to move.
    /// Throws without deleting anything if a move fails.
    static func backUpStore(
        at storeURL: URL,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL? {
        guard fileManager.fileExists(atPath: storeURL.path) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupBase = storeURL.path + ".backup-" + formatter.string(from: now)

        var moved: [(from: URL, to: URL)] = []
        do {
            for suffix in suffixes {
                let from = URL(fileURLWithPath: storeURL.path + suffix)
                guard fileManager.fileExists(atPath: from.path) else { continue }
                let to = URL(fileURLWithPath: backupBase + suffix)
                try fileManager.moveItem(at: from, to: to)
                moved.append((from, to))
            }
        } catch {
            // Put back whatever was already moved so the store isn't left half-split.
            for pair in moved.reversed() {
                try? fileManager.moveItem(at: pair.to, to: pair.from)
            }
            throw error
        }
        return URL(fileURLWithPath: backupBase)
    }
}
