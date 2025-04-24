import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AddLiquidityAndCollectModule = buildModule("AddLiquidityAndCollectModule", (m) => {
    const proxyAdminOwner = m.getAccount(0);

    const addLiquidity = m.contract("UniswapV3AddLiquidity")
    // const collect = m.contract("UniswapV3Collect")

    // Get the parameters
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const router = m.getParameter("router");

    // Encode the initialize function calls
    const addLiquidityInit = m.encodeFunctionCall(addLiquidity, "initialize", [positionManager, factory, router]);
    // const collectInit = m.encodeFunctionCall(collect, "initialize", [positionManager]);

    // Deploy the proxy for the add liquidity strategy
    const addLiquidityProxy = m.contract("TransparentUpgradeableProxy", [addLiquidity, proxyAdminOwner, addLiquidityInit], { id: "StrategiesUniswapV3AddLiquidityProxy" });
    const addLiquidityProxyAdminAddress = m.readEventArgument(addLiquidityProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3AddLiquidityAdmin" });
    const addLiquidityProxyAdmin = m.contractAt("ProxyAdmin", addLiquidityProxyAdminAddress, { id: "StrategiesUniswapV3AddLiquidityProxyAdmin" });

    // Deploy the proxy for the collect strategy
    // const collectProxy = m.contract("TransparentUpgradeableProxy", [collect, proxyAdminOwner, collectInit], { id: "StrategiesUniswapV3CollectProxy" });
    // const collectProxyAdminAddress = m.readEventArgument(collectProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3CollectAdmin" });
    // const collectProxyAdmin = m.contractAt("ProxyAdmin", collectProxyAdminAddress, { id: "StrategiesUniswapV3CollectProxyAdmin" });

    // Set the manager to approve the strategies
    const managerAddress = m.getParameter("ManagerAddr");
    const manager = m.contractAt("Manager", managerAddress, { id: "Manager" });
    m.call(manager, "setApprovedStrategies", [
        [addLiquidityProxy],
        true
    ])

    // Return the proxies and the corresponding proxy admins
    return { addLiquidityProxy, addLiquidityProxyAdmin}
});

export default AddLiquidityAndCollectModule;