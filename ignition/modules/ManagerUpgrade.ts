import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ManagerProxyModule from "./ManagerWithProxy";


const ManagerUpgradeModule = buildModule("ManagerUpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  const { proxyAdmin, proxy } = m.useModule(ManagerProxyModule)

  const managerV1Impl = m.contract("Manager", [], {id: "ManagerV1Impl"});

  const upgradeCall = "0x";
  // If there is a call needed to initialize the new manager, encode it here
  // const upgradeCall = m.encodeFunctionCall(manager02, "upgrade", [proxyAdminOwner, m.getParameter("positionManager")]);

  m.call(proxyAdmin, "upgradeAndCall", [proxy, managerV1Impl, upgradeCall], {
    from: proxyAdminOwner,
  });

  const managerV1 = m.contractAt("Manager", proxy);
  return { proxyAdmin, proxy, managerV1 }
});

export default ManagerUpgradeModule;
