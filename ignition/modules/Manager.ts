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
  m.call(manager, "initialize", [deployer, m.getParameter("positionManager"), userVaultFactory]);
  return { manager }
});

export default ManagerModule;
