import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UpgradeUserVaultModule = buildModule("UpgradeUserVaultModule", (m) => {
//   const proxyAdminOwner = m.getAccount(0);

  // Get existing UserVaultFactory beacon
  const existingUserVaultFactory = m.contractAt("UserVaultFactory", "0xf938078B1900BF50D8E0c86d5C19c6f3Ed989B8d");

  // Deploy new UserVault implementation
  const newUserVaultImpl = m.contract("UserVault", [], { id: "UserVaultImpl01" });

  // Upgrade the beacon to point to new implementation
  m.call(existingUserVaultFactory, "upgradeTo", [newUserVaultImpl]);

  return { newUserVaultImpl };
});

export default UpgradeUserVaultModule;
