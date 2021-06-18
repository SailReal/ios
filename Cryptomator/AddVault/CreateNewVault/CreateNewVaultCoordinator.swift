//
//  CreateNewVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

class CreateNewVaultCoordinator: AccountListing, CloudChoosing, Coordinator {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?

	private let vaultName: String

	init(navigationController: UINavigationController, vaultName: String) {
		self.navigationController = navigationController
		self.vaultName = vaultName
	}

	func start() {
		let viewModel = ChooseCloudViewModel(clouds: [.dropbox, .googleDrive, .oneDrive, .webDAV, .localFileSystem], headerTitle: NSLocalizedString("addVault.createNewVault.chooseCloud.header", comment: ""))
		let chooseCloudVC = ChooseCloudViewController(viewModel: viewModel)
		chooseCloudVC.title = NSLocalizedString("addVault.createNewVault.title", comment: "")
		chooseCloudVC.coordinator = self
		navigationController.pushViewController(chooseCloudVC, animated: true)
	}

	func showAccountList(for cloudProviderType: CloudProviderType) {
		let viewModel = AccountListViewModel(with: cloudProviderType)
		let accountListVC = AccountListViewController(with: viewModel)
		accountListVC.coordinator = self
		navigationController.pushViewController(accountListVC, animated: true)
	}

	func showAddAccount(for cloudProviderType: CloudProviderType, from viewController: UIViewController) {
		let authenticator = CloudAuthenticator(accountManager: CloudProviderAccountManager.shared)
		authenticator.authenticate(cloudProviderType, from: viewController).then { account in
			let provider = try CloudProviderManager.shared.getProvider(with: account.accountUID)
			self.startFolderChooser(with: provider, account: account)
		}
	}

	func selectedAccont(_ account: AccountInfo) throws {
		let provider = try CloudProviderManager.shared.getProvider(with: account.accountUID)
		startFolderChooser(with: provider, account: account.cloudProviderAccount)
	}

	private func startFolderChooser(with provider: CloudProvider, account: CloudProviderAccount) {
		let child = AuthenticatedCreateNewVaultCoordinator(navigationController: navigationController, provider: provider, account: account)
		childCoordinators.append(child)
		child.parentCoordinator = self
		child.start()
	}

	func showEdit(for account: AccountInfo) {}

	func close() {
		navigationController.dismiss(animated: true)
//		parentCoordinator?.close()
	}
}

private class AuthenticatedCreateNewVaultCoordinator: FolderChoosing, Coordinator {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: CreateNewVaultCoordinator?

	let provider: CloudProvider
	let account: CloudProviderAccount

	init(navigationController: UINavigationController, provider: CloudProvider, account: CloudProviderAccount) {
		self.navigationController = navigationController
		self.provider = provider
		self.account = account
	}

	func start() {
		showItems(for: CloudPath("/"))
	}

	// MARK: - FolderChoosing

	func showItems(for path: CloudPath) {
		let viewModel = ChooseFolderViewModel(canCreateFolder: true, cloudPath: path, provider: provider)
		let chooseFolderVC = CreateNewVaultChooseFolderViewController(with: viewModel)
		chooseFolderVC.coordinator = self
		navigationController.pushViewController(chooseFolderVC, animated: true)
	}

	func close() {
		parentCoordinator?.close()
	}

	func chooseItem(_ item: Item) {
		switch item.type {
		default:
			handleError(ExistingVaultCoordinatorError.wrongItemType, for: navigationController)
			return
		}
	}

	func showCreateNewFolder(parentPath: CloudPath) {
		let modalNavigationController = UINavigationController()
		let child = AuthenticatedFolderCreationCoordinator(navigationController: modalNavigationController, provider: provider, parentPath: parentPath)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}
}

private class AuthenticatedFolderCreationCoordinator: FolderCreating, ChildCoordinator {
	weak var parentCoordinator: Coordinator?
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	private let provider: CloudProvider
	private let parentPath: CloudPath

	init(navigationController: UINavigationController, provider: CloudProvider, parentPath: CloudPath) {
		self.navigationController = navigationController
		self.provider = provider
		self.parentPath = parentPath
	}

	func start() {
		let viewModel = CreateNewFolderViewModel(parentPath: parentPath, provider: provider)
		let createNewFolderVC = CreateNewFolderViewController(viewModel: viewModel)
		createNewFolderVC.title = NSLocalizedString("common.button.createFolder", comment: "")
		createNewFolderVC.coordinator = self
		navigationController.pushViewController(createNewFolderVC, animated: false)
	}

	func createdNewFolder(at folderPath: CloudPath) {
		navigationController.dismiss(animated: true)
		if let folderChoosingParentCoordinator = parentCoordinator as? FolderChoosing {
			folderChoosingParentCoordinator.showItems(for: folderPath)
		}
		parentCoordinator?.childDidFinish(self)
	}

	func stop() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
