//
//  UploadTaskDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 06.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

protocol UploadTaskManager {
	func createNewTaskRecord(for itemMetadata: ItemMetadata) throws -> UploadTaskRecord
	func getTaskRecord(for id: Int64) throws -> UploadTaskRecord?
	func updateTaskRecord(with id: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String) throws
	func updateTaskRecord(_ task: inout UploadTaskRecord, error: NSError) throws
	func getCorrespondingTaskRecords(ids: [Int64]) throws -> [UploadTaskRecord?]
	func removeTaskRecord(for id: Int64) throws
	func getTask(for uploadTask: UploadTaskRecord) throws -> UploadTask
}

extension UploadTaskManager {
	func getTaskRecord(for itemMetadata: ItemMetadata) throws -> UploadTaskRecord? {
		guard let id = itemMetadata.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		return try getTaskRecord(for: id)
	}

	func getTaskRecords(for itemMetadata: [ItemMetadata]) throws -> [UploadTaskRecord?] {
		let ids: [Int64] = try itemMetadata.map {
			guard let id = $0.id else {
				throw DBManagerError.nonSavedItemMetadata
			}
			return id
		}
		return try getCorrespondingTaskRecords(ids: ids)
	}

	func removeTaskRecord(for itemMetadata: ItemMetadata) throws {
		guard let id = itemMetadata.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		try removeTaskRecord(for: id)
	}
}

class UploadTaskDBManager: UploadTaskManager {
	let dbPool: DatabasePool

	init(with dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	func createNewTaskRecord(for itemMetadata: ItemMetadata) throws -> UploadTaskRecord {
		return try dbPool.write { db in
			let task = UploadTaskRecord(correspondingItem: itemMetadata.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
			try task.save(db)
			return task
		}
	}

	func getTaskRecord(for id: Int64) throws -> UploadTaskRecord? {
		let uploadTask = try dbPool.read { db in
			return try UploadTaskRecord.fetchOne(db, key: id)
		}
		return uploadTask
	}

	func updateTaskRecord(with id: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String) throws {
		try dbPool.write { db in
			if var task = try UploadTaskRecord.fetchOne(db, key: id) {
				task.lastFailedUploadDate = lastFailedUploadDate
				task.uploadErrorCode = uploadErrorCode
				task.uploadErrorDomain = uploadErrorDomain
				try task.update(db)
			} else {
				throw DBManagerError.taskNotFound
			}
		}
	}

	func updateTaskRecord(_ task: inout UploadTaskRecord, error: NSError) throws {
		_ = try dbPool.write { db in
			task.lastFailedUploadDate = Date()
			task.uploadErrorCode = error.code
			task.uploadErrorDomain = error.domain
			try task.update(db)
		}
	}

	func getCorrespondingTaskRecords(ids: [Int64]) throws -> [UploadTaskRecord?] {
		let uploadTasks: [UploadTaskRecord?] = try dbPool.read { db in
			var tasks = [UploadTaskRecord?]()
			for id in ids {
				let task = try UploadTaskRecord.fetchOne(db, key: id)
				tasks.append(task)
			}
			return tasks
		}
		return uploadTasks
	}

	func removeTaskRecord(for id: Int64) throws {
		_ = try dbPool.write { db in
			try UploadTaskRecord.deleteOne(db, key: id)
		}
	}

	func getTask(for uploadTask: UploadTaskRecord) throws -> UploadTask {
		try dbPool.read { db in
			guard let itemMetadata = try uploadTask.itemMetadata.fetchOne(db) else {
				throw DBManagerError.missingItemMetadata
			}
			return UploadTask(taskRecord: uploadTask, itemMetadata: itemMetadata)
		}
	}
}
