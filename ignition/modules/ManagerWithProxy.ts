import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerProxyModule = buildModule("ManagerProxyModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  // Deploy UserVault implementation
  const userVaultImpl = m.contract("UserVault");
  // Deploy UserVaultFactory
  const userVaultFactory = m.contract("UserVaultFactory", [userVaultImpl, proxyAdminOwner]);
  // Deploy Manager
  const managerImpl = m.contract("Manager", [], { id: "ManagerImpl" });
 
  // Encode the initialize function call
  const initializeCall = m.encodeFunctionCall(managerImpl, "initialize", [proxyAdminOwner, userVaultFactory]);

  // Deploy the proxy contract with the manager contract as the implementation
  const proxy = m.contract("TransparentUpgradeableProxy", [
    managerImpl,
    proxyAdminOwner,
    initializeCall,
  ]);

  // Get the address of the proxy admin
  const proxyAdminAddress = m.readEventArgument(proxy, "AdminChanged", "newAdmin");
  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);
  const manager = m.contractAt("Manager", proxy);

  return { proxyAdmin, proxy, userVaultFactory, manager }
});

export default ManagerProxyModule;
