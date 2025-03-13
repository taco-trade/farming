import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerModule = buildModule("ManagerModule", (m) => {
  const manager = m.contract("Manager");
  m.call(manager, "initialize", [m.getParameter("positionManager")]);
  return { manager }
});

export default ManagerModule;
