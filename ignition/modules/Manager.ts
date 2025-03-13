import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerModule = buildModule("ManagerModule", (m) => {
  const deployer = m.getAccount(0);
  const manager = m.contract("Manager");
  m.call(manager, "initialize", [deployer, m.getParameter("positionManager")]);
  return { manager }
});

export default ManagerModule;
