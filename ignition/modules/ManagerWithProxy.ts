import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerProxyModule = buildModule("ManagerProxyModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  // Deploy UserVault implementation
  const userVaultImpl = m.contract("UserVault");
  // Deploy UserVaultFactory
  const userVaultFactory = m.contract("UserVaultFactory", [userVaultImpl, proxyAdminOwner]);
  // Deploy Manager
  const manager = m.contract("Manager");
 
  // Encode the initialize function call
  const initializeCall = m.encodeFunctionCall(manager, "initialize", [proxyAdminOwner, userVaultFactory]);

  // Deploy the proxy contract with the manager contract as the implementation
  const proxy = m.contract("TransparentUpgradeableProxy", [
    manager,
    proxyAdminOwner,
    initializeCall,
  ]);

  // Get the address of the proxy admin
  const proxyAdminAddress = m.readEventArgument(proxy, "AdminChanged", "newAdmin");
  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

  return { proxyAdmin, proxy, userVaultFactory }
});

export default ManagerProxyModule;
