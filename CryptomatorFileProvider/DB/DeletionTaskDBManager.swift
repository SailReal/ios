//
//  DeletionTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
protocol DeletionTaskManager {
	func createTaskRecord(for item: ItemMetadata) throws -> DeletionTaskRecord
	func getTaskRecord(for id: Int64) throws -> DeletionTaskRecord
	func removeTaskRecord(_ task: DeletionTaskRecord) throws
	func getTaskRecordsForItemsWhichWere(in parentId: Int64) throws -> [DeletionTaskRecord]
	func getTask(for id: DeletionTaskRecord) throws -> DeletionTask
}

enum DeletionTaskManagerError: Error {
	case missingItemMetadata
}

class DeletionTaskDBManager: DeletionTaskManager {
	let dbPool: DatabasePool

	init(with dbPool: DatabasePool) throws {
		self.dbPool = dbPool
		_ = try dbPool.write { db in
			try DeletionTaskRecord.deleteAll(db)
		}
	}

	func createTaskRecord(for item: ItemMetadata) throws -> DeletionTaskRecord {
		try dbPool.write { db in
			let task = DeletionTaskRecord(correspondingItem: item.id!, cloudPath: item.cloudPath, parentId: item.parentId, itemType: item.type)
			try task.save(db)
			return task
		}
	}

	func getTaskRecord(for id: Int64) throws -> DeletionTaskRecord {
		try dbPool.read { db in
			guard let task = try DeletionTaskRecord.fetchOne(db, key: id) else {
				throw TaskError.taskNotFound
			}
			return task
		}
	}

	func removeTaskRecord(_ task: DeletionTaskRecord) throws {
		_ = try dbPool.write { db in
			try task.delete(db)
		}
	}

	func getTaskRecordsForItemsWhichWere(in parentId: Int64) throws -> [DeletionTaskRecord] {
		let tasks: [DeletionTaskRecord] = try dbPool.read { db in
			return try DeletionTaskRecord
				.filter(Column("parentId") == parentId)
				.fetchAll(db)
		}
		return tasks
	}

	func getTask(for deletionTask: DeletionTaskRecord) throws -> DeletionTask {
		try dbPool.read { db in
			guard let itemMetadata = try deletionTask.itemMetadata.fetchOne(db) else {
				throw DeletionTaskManagerError.missingItemMetadata
			}
			return DeletionTask(taskRecord: deletionTask, itemMetadata: itemMetadata)
		}
	}
}