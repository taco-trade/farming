import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerProxyModule = buildModule("ManagerProxyModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  // Deploy the manager contract
  const manager = m.contract("Manager");

  // Encode the initialize function call
  const initializeCall = m.encodeFunctionCall(manager, "initialize", [proxyAdminOwner, m.getParameter("positionManager")]);

  // Deploy the proxy contract with the manager contract as the implementation
  const proxy = m.contract("TransparentUpgradeableProxy", [
    manager,
    proxyAdminOwner,
    initializeCall,
  ]);

  // Get the address of the proxy admin
  const proxyAdminAddress = m.readEventArgument(proxy, "AdminChanged", "newAdmin");
  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

  return { proxyAdmin, proxy }
});

export default ManagerProxyModule;
