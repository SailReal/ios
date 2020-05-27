//
//  MockGoogleDriveAuthenticationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 25.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest

class MockGoogleDriveAuthenticationTests: XCTestCase {
	/**
	    It is necessary to call another function than canAuthorize, because it returns true as soon as any refreshToken is set and does not check it online for correctness before.
	 */
	func testAuthenticationWorksWithoutViewController() throws {
		let expectation = XCTestExpectation(description: "Google Authentication works without ViewController")
		let authentication = MockGoogleDriveCloudAuthentication(withRefreshToken: IntegrationTestSecrets.googleDriveRefreshToken)
		authentication.authenticate().then {
			authentication.authorization?.authorizeRequest(nil, completionHandler: { error in
				XCTAssertNil(error)
				expectation.fulfill()
	 })
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}
}