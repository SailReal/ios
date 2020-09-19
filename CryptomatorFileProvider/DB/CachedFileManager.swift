//
//  CachedFileManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

private struct CachedEntry: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "cachedFiles"
	static let lastModifiedDateKey = "lastModifiedDate"
	static let correspondingItemKey = "correspondingItem"
	let lastModifiedDate: Date?
	let correspondingItem: Int64
}

extension CachedEntry: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[CachedEntry.lastModifiedDateKey] = lastModifiedDate
		container[CachedEntry.correspondingItemKey] = correspondingItem
	}
}

class CachedFileManager {
	let dbQueue: DatabaseQueue

	init(with dbQueue: DatabaseQueue) {
		self.dbQueue = dbQueue
	}

	func hasCurrentVersionLocal(for identifier: Int64, with lastModifiedDateInCloud: Date) throws -> Bool {
		let fetchedEntry = try dbQueue.read { db in
			return try CachedEntry.fetchOne(db, key: identifier)
		}
		guard let cachedEntry = fetchedEntry, let lastModifiedDateLocal = cachedEntry.lastModifiedDate else {
			return false
		}
		return lastModifiedDateLocal == lastModifiedDateInCloud
	}

	func getLastModifiedDate(for identifier: Int64) throws -> Date? {
		let fetchedEntry = try dbQueue.read { db in
			return try CachedEntry.fetchOne(db, key: identifier)
		}
		return fetchedEntry?.lastModifiedDate
	}

	func cacheLocalFileInfo(for identifier: Int64, lastModifiedDate: Date?) throws {
		try dbQueue.write { db in
			try CachedEntry(lastModifiedDate: lastModifiedDate, correspondingItem: identifier).save(db)
		}
	}

	/**
	 - returns: `true` If an entry was really deleted. `false` If an entry did not exist.
	 */
	func removeCachedEntry(for identifier: Int64) throws -> Bool {
		return try dbQueue.write { db in
			let hasDeletedEntry = try CachedEntry.deleteOne(db, key: identifier)
			return hasDeletedEntry
		}
	}

	func removeCachedFile(for identifier: Int64, at localURL: URL) throws {
		return try dbQueue.write { db in
			if let entry = try CachedEntry.fetchOne(db, key: identifier) {
				try FileManager.default.removeItem(at: localURL)
				try entry.delete(db)
			}
		}
	}
}