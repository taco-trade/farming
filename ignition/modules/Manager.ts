import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerModule = buildModule("ManagerModule", (m) => {
  const deployer = m.getAccount(0);
  // Deploy UserVault implementation
  const userVaultImpl = m.contract("UserVault");
  // Deploy UserVaultFactory
  const userVaultFactory = m.contract("UserVaultFactory", [userVaultImpl, deployer]);
  // Deploy Manager
  const manager = m.contract("Manager");
  // Initialize Manager
  m.call(manager, "initialize", [deployer, userVaultFactory]);
  return { manager }
});

export default ManagerModule;
