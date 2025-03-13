import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ManagerModule = buildModule("ManagerModule", (m) => {
  const manager = m.contract("Manager", [
    m.getParameter("owner"),
    m.getParameter("nftPositionManager"),
  ]);

  const mintStrategy = m.contract("PancakeSwapV3Mint", [
    m.getParameter("factory"),
    m.getParameter("router"),
    m.getParameter("nftPositionManager"),
  ]);

  const decreaseLiquidityStrategy = m.contract("PancakeSwapV3DecreaseLiquidity", [
    m.getParameter("nftPositionManager"),
  ]);

  return { manager, mintStrategy, decreaseLiquidityStrategy };
});

export default ManagerModule;
