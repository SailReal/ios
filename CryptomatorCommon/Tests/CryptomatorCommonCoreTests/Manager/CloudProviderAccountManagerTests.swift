//
//  CloudProviderAccountManagerTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
import XCTest
@testable import CryptomatorCommonCore

class CloudProviderAccountManagerTests: XCTestCase {
	var accountManager: CloudProviderAccountDBManager!
	var tmpDir: URL!

	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		let dbPool = try DatabasePool(path: tmpDir.appendingPathComponent("db.sqlite").path)
		try dbPool.write { db in
			try db.create(table: CloudProviderAccount.databaseTableName) { table in
				table.column(CloudProviderAccount.accountUIDKey, .text).primaryKey()
				table.column(CloudProviderAccount.cloudProviderTypeKey, .text).notNull()
			}
		}
		accountManager = CloudProviderAccountDBManager(dbPool: dbPool)
	}

	override func tearDownWithError() throws {
		accountManager = nil
		try FileManager.default.removeItem(at: tmpDir)
	}

	func testSaveAccount() throws {
		let accountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: accountUID, cloudProviderType: .googleDrive)
		try accountManager.saveNewAccount(account)
		let fetchedCloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		XCTAssertEqual(CloudProviderType.googleDrive, fetchedCloudProviderType)
	}

	func testRemoveAccount() throws {
		let accountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: accountUID, cloudProviderType: .googleDrive)
		try accountManager.saveNewAccount(account)
		let fetchedCloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		XCTAssertEqual(CloudProviderType.googleDrive, fetchedCloudProviderType)
		try accountManager.removeAccount(with: accountUID)
		XCTAssertThrowsError(try accountManager.getCloudProviderType(for: accountUID)) { error in
			guard case CloudProviderAccountError.accountNotFoundError = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGellAccountUIDsForCloudProviderType() throws {
		let accountUIDs = [
			UUID().uuidString,
			UUID().uuidString,
			UUID().uuidString,
			UUID().uuidString
		]
		let accounts = [
			CloudProviderAccount(accountUID: accountUIDs[0], cloudProviderType: .googleDrive),
			CloudProviderAccount(accountUID: accountUIDs[1], cloudProviderType: .googleDrive),
			CloudProviderAccount(accountUID: accountUIDs[2], cloudProviderType: .dropbox),
			CloudProviderAccount(accountUID: accountUIDs[3], cloudProviderType: .googleDrive)
		]
		for account in accounts {
			try accountManager.saveNewAccount(account)
		}
		let fetchedAccountUIDsForGoogleDrive = try accountManager.getAllAccountUIDs(for: .googleDrive)
		XCTAssertEqual(3, fetchedAccountUIDsForGoogleDrive.count)
		XCTAssert(fetchedAccountUIDsForGoogleDrive.contains { $0 == accounts[0].accountUID })
		XCTAssert(fetchedAccountUIDsForGoogleDrive.contains { $0 == accounts[1].accountUID })
		XCTAssert(fetchedAccountUIDsForGoogleDrive.contains { $0 == accounts[3].accountUID })

		let fetchedAccountUIDsForDropbox = try accountManager.getAllAccountUIDs(for: .dropbox)
		XCTAssertEqual(1, fetchedAccountUIDsForDropbox.count)
		XCTAssert(fetchedAccountUIDsForDropbox.contains { $0 == accounts[2].accountUID })
	}
}
