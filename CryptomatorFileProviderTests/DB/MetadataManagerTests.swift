//
//  MetadataManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import GRDB
import XCTest
@testable import CryptomatorFileProvider
class MetadataManagerTests: XCTestCase {
	var manager: MetadataManager!
	var tmpDirURL: URL!
	var dbQueue: DatabaseQueue!

	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		dbQueue = try DataBaseHelper.getDBMigratedQueue(at: dbURL.path)
		manager = MetadataManager(with: dbQueue)
	}

	override func tearDownWithError() throws {
		dbQueue = nil
		manager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCacheMetadataForFile() throws {
		let cloudPath = CloudPath("/TestFile")

		let itemMetadata = ItemMetadata(name: "TestFile", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		XCTAssertNil(itemMetadata.id)
		try manager.cacheMetadata(itemMetadata)
		XCTAssertNotNil(itemMetadata.id)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: cloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
		XCTAssertNotNil(fetchedMetadata.id)
	}

	func testCacheMetadataForFolder() throws {
		let cloudPath = CloudPath("/Test Folder/")

		let itemMetadata = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: true)
		XCTAssertNil(itemMetadata.id)
		try manager.cacheMetadata(itemMetadata)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: cloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
		XCTAssertNotNil(fetchedMetadata.id)
	}

	func testCacheMultipleEntries() throws {
		let fileCloudPath = CloudPath("/TestFile")
		let folderCloudPath = CloudPath("/TestFolder/")
		let itemMetadataForFile = ItemMetadata(name: "TestFile", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: true)
		XCTAssertNil(itemMetadataForFile.id)
		XCTAssertNil(itemMetadataForFolder.id)
		let metadatas = [itemMetadataForFile, itemMetadataForFolder]
		try manager.cacheMetadatas(metadatas)
		guard let fetchedMetadataForFile = try manager.getCachedMetadata(for: fileCloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFile, fetchedMetadataForFile)
		XCTAssertNotNil(fetchedMetadataForFile.id)
		guard let fetchedMetadataForFolder = try manager.getCachedMetadata(for: folderCloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFolder, fetchedMetadataForFolder)
		XCTAssertNotNil(fetchedMetadataForFolder.id)
	}

	func testGetPlaceholderItems() throws {
		let fileCloudPath = CloudPath("/Test File.txt")
		let folderCloudPath = CloudPath("/Test Folder/")
		let secondFolderCloudPath = CloudPath("/SecondFolder/")
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: true)
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: secondFolderCloudPath, isPlaceholderItem: false)
		XCTAssertNil(placeholderItemMetadataForFile.id)
		XCTAssertNil(placeholderItemMetadataForFolder.id)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadatas([placeholderItemMetadataForFile, placeholderItemMetadataForFolder, itemMetadataForFolder])
		let fetchedPlaceholderItems = try manager.getPlaceholderMetadata(for: MetadataManager.rootContainerId)
		XCTAssertEqual(2, fetchedPlaceholderItems.count)
		XCTAssertEqual([placeholderItemMetadataForFile, placeholderItemMetadataForFolder], fetchedPlaceholderItems)
		XCTAssertNotNil(fetchedPlaceholderItems[0].id)
		XCTAssertNotNil(fetchedPlaceholderItems[1].id)
		XCTAssertNotEqual(fetchedPlaceholderItems[0].id, fetchedPlaceholderItems[1].id)
	}

	func testGetPlaceholderItemsIsEmptyForNoPlaceholderItemsUnderParent() throws {
		let fileCloudPath = CloudPath("/Test File.txt")
		let folderCloudPath = CloudPath("/Test Folder/")
		let secondFolderCloudPath = CloudPath("/Test Folder/SecondFolder/")
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		XCTAssertNil(placeholderItemMetadataForFile.id)
		XCTAssertNil(placeholderItemMetadataForFolder.id)
		try manager.cacheMetadatas([placeholderItemMetadataForFile, placeholderItemMetadataForFolder])
		XCTAssertNotNil(placeholderItemMetadataForFile.id)
		guard let testFolderId = placeholderItemMetadataForFolder.id else {
			XCTFail("Test Folder ID is nil")
			return
		}
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentId: testFolderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: secondFolderCloudPath, isPlaceholderItem: true)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadata(itemMetadataForFolder)
		XCTAssertNotNil(itemMetadataForFolder.id)
		let fetchedPlaceholderItems = try manager.getPlaceholderMetadata(for: MetadataManager.rootContainerId)
		XCTAssert(fetchedPlaceholderItems.isEmpty)
	}

	func testOverwriteMetadata() throws {
		let cloudPath = CloudPath("/TestFolder/")

		let itemMetadata = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		guard let id = itemMetadata.id else {
			XCTFail("Metadata has no id")
			return
		}
		guard let fetchedItemMetadata = try manager.getCachedMetadata(for: id) else {
			XCTFail("Metadata not stored correctly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedItemMetadata)
		let changedItemMetadataAtSameRemoteURL = ItemMetadata(name: "TestFolder", type: .folder, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(changedItemMetadataAtSameRemoteURL)

		XCTAssertEqual(id, changedItemMetadataAtSameRemoteURL.id)
		guard let fetchedChangedItemMetadata = try manager.getCachedMetadata(for: id) else {
			XCTFail("Metadata not stored correctly")
			return
		}
		XCTAssertEqual(changedItemMetadataAtSameRemoteURL, fetchedChangedItemMetadata)
	}

	func testGetCachedMetadataInsideParentId() throws {
		let fileCloudPath = CloudPath("/Existing File.txt")
		let folderCloudPath = CloudPath("/Existing Folder/")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		XCTAssertNil(itemMetadataForFile.id)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadatas([itemMetadataForFile, itemMetadataForFolder])
		XCTAssertNotNil(itemMetadataForFile.id)
		XCTAssertNotNil(itemMetadataForFolder.id)
		let cachedMetadata = try manager.getCachedMetadata(forParentId: MetadataManager.rootContainerId)
		XCTAssertEqual(2, cachedMetadata.count)
		XCTAssertFalse(cachedMetadata.contains { $0.id == MetadataManager.rootContainerId })
		XCTAssert(cachedMetadata.contains { $0 == itemMetadataForFile })
		XCTAssert(cachedMetadata.contains { $0 == itemMetadataForFolder })
	}

	func testFlagAllNonPlaceholderItemsAsCacheCleanupCandidates() throws {
		let placeholderFileCloudPath = CloudPath("/Placeholder File.txt")
		let placeholderFolderCloudPath = CloudPath("/Placeholder Folder/")
		let placeholderItemMetadataForFile = ItemMetadata(name: "Placeholder File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: placeholderFileCloudPath, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Placeholder Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: placeholderFolderCloudPath, isPlaceholderItem: true)
		let fileCloudPath = CloudPath("/Existing File.txt")
		let folderCloudPath = CloudPath("/Existing Folder/")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadatas([placeholderItemMetadataForFile, placeholderItemMetadataForFolder, itemMetadataForFile, itemMetadataForFolder])
		try manager.flagAllItemsAsMaybeOutdated(insideParentId: MetadataManager.rootContainerId)
		let cachedMetadata = try manager.getCachedMetadata(forParentId: MetadataManager.rootContainerId)
		XCTAssertEqual(4, cachedMetadata.count)
		XCTAssert(cachedMetadata.contains { $0.name == "Placeholder File.txt" && !$0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Placeholder Folder" && !$0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Existing File.txt" && $0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Existing Folder" && $0.isMaybeOutdated })
	}

	func testSynchronizeWithTasks() throws {
		let placeholderFileCloudPath = CloudPath("/Placeholder File.txt")
		let placeholderItemMetadataForFile = ItemMetadata(name: "Placeholder File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: placeholderFileCloudPath, isPlaceholderItem: true)
		let fileCloudPath = CloudPath("/Existing File.txt")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let folderCloudPath = CloudPath("/Existing Folder/")
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		let metadata = [placeholderItemMetadataForFile, itemMetadataForFile, itemMetadataForFolder]
		try manager.cacheMetadatas(metadata)

		let uploadTaskManager = UploadTaskManager(with: dbQueue)
		var taskForPlaceholderItem = try uploadTaskManager.createNewTask(for: placeholderItemMetadataForFile.id!)
		try uploadTaskManager.updateTask(&taskForPlaceholderItem, error: NSError(domain: "TestDomain", code: -1000, userInfo: nil))
		var taskForExistingItem = try uploadTaskManager.createNewTask(for: itemMetadataForFile.id!)
		try uploadTaskManager.updateTask(&taskForExistingItem, error: NSError(domain: "TestDomain", code: -1000, userInfo: nil))
		let taskForExistingFolder = try uploadTaskManager.createNewTask(for: itemMetadataForFolder.id!)
		try uploadTaskManager.updateTask(taskForPlaceholderItem)
		try uploadTaskManager.updateTask(taskForExistingItem)

		try manager.synchronize(metadata: metadata, with: [taskForPlaceholderItem, taskForExistingItem, taskForExistingFolder])
		XCTAssertEqual(ItemStatus.uploadError, metadata[0].statusCode)
		XCTAssertEqual(ItemStatus.uploadError, metadata[1].statusCode)
		XCTAssertEqual(ItemStatus.isUploaded, metadata[2].statusCode)
	}

	func testGetAllCachedMetadataInsideAFolder() throws {
		let fileInFolderCloudPath = CloudPath("/Test Folder/Test File.txt")
		let fileInSubFolderCloudPath = CloudPath("/Test Folder/SecondFolder/Test File.txt")
		let folderCloudPath = CloudPath("/Test Folder/")
		let secondFolderCloudPath = CloudPath("/Test Folder 1/")
		let subFolderCloudPath = CloudPath("/Test Folder/SecondFolder/")

		let itemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		let secondItemMetadataForFolder = ItemMetadata(name: "Test Folder 1", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: secondFolderCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadatas([itemMetadataForFolder, secondItemMetadataForFolder])
		guard let folderId = itemMetadataForFolder.id else {
			XCTFail("Folder has no ID")
			return
		}
		let itemMetadataForFileInFolder = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentId: folderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileInFolderCloudPath, isPlaceholderItem: false)
		let itemMetadataForSubFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentId: folderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: subFolderCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForSubFolder)
		guard let subFolderId = itemMetadataForSubFolder.id else {
			XCTFail("Folder has no ID")
			return
		}
		let itemMetadataForFileInSubFolder = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentId: subFolderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileInSubFolderCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadatas([itemMetadataForFileInFolder, itemMetadataForFileInSubFolder])
		let cachedMetadata = try manager.getAllCachedMetadata(inside: itemMetadataForFolder)

		XCTAssertEqual(3, cachedMetadata.count)
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == itemMetadataForFileInFolder.id! }))
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == subFolderId }))
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == itemMetadataForFileInSubFolder.id! }))
	}
}

extension ItemMetadata: Comparable {
	public static func < (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}

	public static func == (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.type == rhs.type && lhs.size == rhs.size && lhs.parentId == rhs.parentId && lhs.lastModifiedDate == rhs.lastModifiedDate && lhs.statusCode == rhs.statusCode && lhs.cloudPath == rhs.cloudPath && lhs.isPlaceholderItem == rhs.isPlaceholderItem && lhs.isMaybeOutdated == rhs.isMaybeOutdated
	}
}