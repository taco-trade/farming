import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UpgradeUserVaultModule = buildModule("UpgradeUserVaultModule", (m) => {
//   const proxyAdminOwner = m.getAccount(0);

  const userVaultFactoryAddr = m.getParameter("UserVaultFactory");

  // Get existing UserVaultFactory beacon
  const existingUserVaultFactory = m.contractAt("UserVaultFactory", userVaultFactoryAddr);

  // Deploy new UserVault implementation
  const newUserVaultImpl = m.contract("UserVault", [], { id: "UserVaultImpl01" });

  // Upgrade the beacon to point to new implementation
  m.call(existingUserVaultFactory, "upgradeTo", [newUserVaultImpl]);

  return { newUserVaultImpl };
});

export default UpgradeUserVaultModule;
