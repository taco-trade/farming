import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const ManagerUpgradeModule = buildModule("ManagerUpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  const proxyAddr = m.getParameter("ManagerProxy");
  const proxyAdminAddr = m.getParameter("ManagerProxyAdmin");

  const proxy = m.contractAt("TransparentUpgradeableProxy", proxyAddr);
  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddr);
  const managerV1Impl = m.contract("Manager", [], {id: "ManagerV1Impl"});

  const upgradeCall = "0x";
  // If there is a call needed to initialize the new manager, encode it here
  // const upgradeCall = m.encodeFunctionCall(manager02, "upgrade", [proxyAdminOwner, m.getParameter("positionManager")]);

  m.call(proxyAdmin, "upgradeAndCall", [proxyAddr, managerV1Impl, upgradeCall], {
    from: proxyAdminOwner,
  });

  const managerV1 = m.contractAt("Manager", proxyAddr);
  return { proxy, proxyAdmin, managerV1 }
});

export default ManagerUpgradeModule;
