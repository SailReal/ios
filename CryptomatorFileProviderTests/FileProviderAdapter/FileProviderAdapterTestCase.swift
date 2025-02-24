//
//  FileProviderAdapterTestCase.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterTestCase: CloudTaskExecutorTestCase {
	var adapter: FileProviderAdapter!
	var localURLProviderMock: LocalURLProviderMock!
	override func setUpWithError() throws {
		try super.setUpWithError()
		localURLProviderMock = LocalURLProviderMock()
		adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 1), provider: cloudProviderMock, localURLProvider: localURLProviderMock)
	}

	class LocalURLProviderMock: LocalURLProvider {
		var response: ((NSFileProviderItemIdentifier) -> URL?)?

		func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
			guard let response = response else {
				fatalError("urlForItem not mocked")
			}
			return response(identifier)
		}
	}

	class WorkflowSchedulerMock: WorkflowScheduler {
		init() {
			super.init(maxParallelUploads: 1, maxParallelDownloads: 1)
		}

		override func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
			return Promise(CloudTaskTestError.correctPassthrough)
		}
	}
}

extension UploadTaskRecord: Equatable {
	public static func == (lhs: UploadTaskRecord, rhs: UploadTaskRecord) -> Bool {
		lhs.correspondingItem == rhs.correspondingItem && lhs.lastFailedUploadDate == rhs.lastFailedUploadDate && lhs.uploadErrorCode == rhs.uploadErrorCode && lhs.uploadErrorDomain == rhs.uploadErrorDomain
	}
}
