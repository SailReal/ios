//
//  MetadataDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation
import GRDB
protocol MetadataManager {
	func getRootContainerID() -> Int64
	func cacheMetadata(_ metadata: ItemMetadata) throws
	func updateMetadata(_ metadata: ItemMetadata) throws
	func cacheMetadatas(_ metadatas: [ItemMetadata]) throws
	func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata?
	func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata?
	func getPlaceholderMetadata(for parentId: Int64) throws -> [ItemMetadata]
	func getCachedMetadata(forParentId parentId: Int64) throws -> [ItemMetadata]
	func flagAllItemsAsMaybeOutdated(insideParentId parentId: Int64) throws
	func getMaybeOutdatedItems(insideParentId parentId: Int64) throws -> [ItemMetadata]
	func removeItemMetadata(with identifier: Int64) throws
	func removeItemMetadata(_ identifiers: [Int64]) throws
	func getCachedMetadata(forIds ids: [Int64]) throws -> [ItemMetadata]
	func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata]
}

extension MetadataManager {
	func getRootContainerID() -> Int64 {
		1
	}
}

class MetadataDBManager: MetadataManager {
	static func getRootContainerID() -> Int64 {
		rootContainerId
	}

	private let dbPool: DatabasePool
	static let rootContainerId: Int64 = 1
	init(with dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	func cacheMetadata(_ metadata: ItemMetadata) throws {
		if let cachedMetadata = try getCachedMetadata(for: metadata.cloudPath) {
			metadata.id = cachedMetadata.id
			metadata.statusCode = cachedMetadata.statusCode
			try updateMetadata(metadata)
		} else {
			try dbPool.write { db in
				try metadata.save(db)
			}
		}
	}

	func updateMetadata(_ metadata: ItemMetadata) throws {
		try dbPool.write { db in
			try metadata.update(db)
		}
	}

	// TODO: Optimize Code and/or DB Scheme
	func cacheMetadatas(_ metadatas: [ItemMetadata]) throws {
		try dbPool.writeInTransaction { db in
			for metadata in metadatas {
				if let cachedMetadata = try ItemMetadata.fetchOne(db, key: ["cloudPath": metadata.cloudPath]) {
					metadata.id = cachedMetadata.id
					metadata.statusCode = cachedMetadata.statusCode
					try metadata.update(db)
				} else {
					try metadata.insert(db)
				}
			}
			return .commit
		}
	}

	/**
	 Returns the item metadata that has the same path.

	 The path is case-insensitively checked for equality.

	 However, it is stored and returned case-preserving in the database, because this is important for the `VaultDecorator` since the two cleartext paths "/foo" and "/Foo" lead to different ciphertext paths.
	 */
	func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbPool.read { db in
			return try ItemMetadata.filter(Column(ItemMetadata.cloudPathKey).lowercased == cloudPath.path.lowercased()).fetchOne(db)
		}
		return itemMetadata
	}

	func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbPool.read { db in
			return try ItemMetadata.fetchOne(db, key: identifier)
		}
		return itemMetadata
	}

	func getPlaceholderMetadata(for parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try dbPool.read { db in
			return try ItemMetadata
				.filter(Column("parentId") == parentId && Column("isPlaceholderItem") && Column("id") != MetadataDBManager.rootContainerId)
				.fetchAll(db)
		}
		return itemMetadata
	}

	func getCachedMetadata(forParentId parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try dbPool.read { db in
			return try ItemMetadata
				.filter(Column("parentId") == parentId && Column("id") != MetadataDBManager.rootContainerId)
				.fetchAll(db)
		}
		return itemMetadata
	}

	// TODO: find a more meaningful name
	func flagAllItemsAsMaybeOutdated(insideParentId parentId: Int64) throws {
		_ = try dbPool.write { db in
			try ItemMetadata
				.filter(Column("parentId") == parentId && !Column("isPlaceholderItem"))
				.fetchAll(db)
				.forEach {
					$0.isMaybeOutdated = true
					try $0.save(db)
				}
		}
	}

	func getMaybeOutdatedItems(insideParentId parentId: Int64) throws -> [ItemMetadata] {
		try dbPool.read { db in
			return try ItemMetadata
				.filter(Column(ItemMetadata.parentIdKey) == parentId && Column(ItemMetadata.isMaybeOutdatedKey))
				.fetchAll(db)
		}
	}

	func removeItemMetadata(with identifier: Int64) throws {
		_ = try dbPool.write { db in
			try ItemMetadata.deleteOne(db, key: identifier)
		}
	}

	func removeItemMetadata(_ identifiers: [Int64]) throws {
		_ = try dbPool.write { db in
			try ItemMetadata.deleteAll(db, keys: identifiers)
		}
	}

	func getCachedMetadata(forIds ids: [Int64]) throws -> [ItemMetadata] {
		try dbPool.read { db in
			return try ItemMetadata.fetchAll(db, keys: ids)
		}
	}

	/**
	 Returns the items that have the item as parent because of its cloud path. This also includes all subfolders including their items.
	 */
	func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata] {
		precondition(parent.type == .folder)
		return try dbPool.read { db in
			let request: QueryInterfaceRequest<ItemMetadata>
			if parent.id == MetadataDBManager.rootContainerId {
				request = ItemMetadata.filter(Column(ItemMetadata.idKey) != MetadataDBManager.rootContainerId)
			} else {
				request = ItemMetadata.filter(Column(ItemMetadata.cloudPathKey).like("\(parent.cloudPath.path + "/")_%"))
			}
			return try request.fetchAll(db)
		}
	}
}