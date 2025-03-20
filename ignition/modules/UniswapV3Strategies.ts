import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ManagerProxyModule from "./ManagerWithProxy";

export enum Strats {
    mint = 0,
    baseTokenOnly = 1,
    decrease = 2,
}

const StrategiesUniswapV3Module = buildModule("StrategiesUniswapV3Module", (m) => {
    const proxyAdminOwner = m.getAccount(0);

    const mintStrategy = m.contract("UniswapV3Mint");
    const addBaseTokenOnlyStrategy = m.contract("UniswapV3StrategyAddBaseTokenOnly")
    const decreaseLiquidityStrategy = m.contract("UniswapV3DecreaseLiquidity")

    // Get the parameters
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const router = m.getParameter("router");

    // Encode the initialize function calls
    const mintInit = m.encodeFunctionCall(mintStrategy, "initialize", [positionManager]);
    const addBaseTokenOnlyInit = m.encodeFunctionCall(addBaseTokenOnlyStrategy, "initialize", [factory, router, positionManager]);
    const decreaseLiquidityInit = m.encodeFunctionCall(decreaseLiquidityStrategy, "initialize", [positionManager]);

    // Deploy the mint strategy
    const mintProxy = m.contract("TransparentUpgradeableProxy", [mintStrategy, proxyAdminOwner, mintInit], { id: "StrategiesUniswapV3MintProxy" });
    const mintProxyAdminAddress = m.readEventArgument(mintProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3MintAdmin" });
    const mintProxyAdmin = m.contractAt("ProxyAdmin", mintProxyAdminAddress, { id: "StrategiesUniswapV3MintProxyAdmin" });

    // Deploy the proxy for the add base token only strategy
    const addBaseTokenOnlyProxy = m.contract("TransparentUpgradeableProxy", [addBaseTokenOnlyStrategy, proxyAdminOwner, addBaseTokenOnlyInit], { id: "StrategiesUniswapV3ABTProxy" });
    const addBaseTokenOnlyProxyAdminAddress = m.readEventArgument(addBaseTokenOnlyProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3ABTAdmin" });
    const addBaseTokenOnlyProxyAdmin = m.contractAt("ProxyAdmin", addBaseTokenOnlyProxyAdminAddress, { id: "StrategiesUniswapV3ABTProxyAdmin" });

    // Deploy the proxy for the decrease liquidity strategy
    const decreaseLiquidityProxy = m.contract("TransparentUpgradeableProxy", [decreaseLiquidityStrategy, proxyAdminOwner, decreaseLiquidityInit], { id: "StrategiesUniswapV3DecProxy" });
    const decreaseLiquidityProxyAdminAddress = m.readEventArgument(decreaseLiquidityProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3DecAdmin" });
    const decreaseLiquidityProxyAdmin = m.contractAt("ProxyAdmin", decreaseLiquidityProxyAdminAddress, { id: "StrategiesUniswapV3DecProxyAdmin" });

    const { manager } = m.useModule(ManagerProxyModule);
    m.call(manager, "setApprovedStrategies", [
        [mintProxy, addBaseTokenOnlyProxy, decreaseLiquidityProxy],
        true
    ])
    // Return the proxies and the corresponding proxy admins
    return { mintProxy, mintProxyAdmin, addBaseTokenOnlyProxy, addBaseTokenOnlyProxyAdmin, decreaseLiquidityProxy, decreaseLiquidityProxyAdmin }
});

export default StrategiesUniswapV3Module;