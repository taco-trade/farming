import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerModule = buildModule("ManagerModule", (m) => {
  const manager = m.contract("Manager", [
    m.getParameter("owner"),
    m.getParameter("nftPositionManager"),
  ]);

  const strategy = m.contract("PancakeSwapV3Mint", [
    m.getParameter("factory"),
    m.getParameter("router"),
    m.getParameter("nftPositionManager"),
  ]);

  return { manager, strategy };
});

export default ManagerModule;
