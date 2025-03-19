import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ManagerModule from "./Manager";


const StrategiesModule = buildModule("StrategiesModule", (m) => {
  const mintStrategy = m.contract("PancakeSwapV3Mint");
  const decreaseLiquidityStrategy = m.contract("PancakeSwapV3DecreaseLiquidity");
  const addBaseTokenOnlyStrategy = m.contract("PancakeswapV3StrategyAddBaseTokenOnly");
  const addBaseTokenOnlyWithCalculateStrategy = m.contract("PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate");

  const positionManager = m.getParameter("positionManager");
  const factory = m.getParameter("factory");
  const router = m.getParameter("router");

  m.call(mintStrategy, "initialize", [positionManager]);
  m.call(decreaseLiquidityStrategy, "initialize", [positionManager]);
  m.call(addBaseTokenOnlyStrategy, "initialize", [factory, router, positionManager]);
  m.call(addBaseTokenOnlyWithCalculateStrategy, "initialize", [factory, router, positionManager]);

  const { manager } = m.useModule(ManagerModule);

  m.call(manager, "setApprovedStrategies", [
    [mintStrategy, decreaseLiquidityStrategy, addBaseTokenOnlyStrategy, addBaseTokenOnlyWithCalculateStrategy],
    true
  ])

  return { mintStrategy, decreaseLiquidityStrategy, addBaseTokenOnlyStrategy, addBaseTokenOnlyWithCalculateStrategy }
});

export default StrategiesModule;