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
    const zapMintStrategy = m.contract("UniswapV3ZapMint")
    const addLiquidityStrategy = m.contract("UniswapV3AddLiquidity")
    const collectStrategy = m.contract("UniswapV3Collect")

    // Get the parameters
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const router = m.getParameter("router");

    // Encode the initialize function calls
    const mintInit = m.encodeFunctionCall(mintStrategy, "initialize", [positionManager]);
    const addBaseTokenOnlyInit = m.encodeFunctionCall(addBaseTokenOnlyStrategy, "initialize", [factory, router, positionManager]);
    const decreaseLiquidityInit = m.encodeFunctionCall(decreaseLiquidityStrategy, "initialize", [positionManager]);
    const zapMintInit = m.encodeFunctionCall(zapMintStrategy, "initialize", [factory, router, positionManager]);
    const addLiquidityInit = m.encodeFunctionCall(addLiquidityStrategy, "initialize", [positionManager, factory, router]);
    const collectInit = m.encodeFunctionCall(collectStrategy, "initialize", [positionManager]);

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

    // Deploy the proxy for the zap mint strategy
    const zapMintProxy = m.contract("TransparentUpgradeableProxy", [zapMintStrategy, proxyAdminOwner, zapMintInit], { id: "StrategiesUniswapV3ZapMintProxy" });
    const zapMintProxyAdminAddress = m.readEventArgument(zapMintProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3ZapMintAdmin" });
    const zapMintProxyAdmin = m.contractAt("ProxyAdmin", zapMintProxyAdminAddress, { id: "StrategiesUniswapV3ZapMintProxyAdmin" });

    // Deploy the proxy for the add liquidity strategy
    const addLiquidityProxy = m.contract("TransparentUpgradeableProxy", [addLiquidityStrategy, proxyAdminOwner, addLiquidityInit], { id: "StrategiesUniswapV3AddLiquidityProxy" });
    const addLiquidityProxyAdminAddress = m.readEventArgument(addLiquidityProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3AddLiquidityAdmin" });
    const addLiquidityProxyAdmin = m.contractAt("ProxyAdmin", addLiquidityProxyAdminAddress, { id: "StrategiesUniswapV3AddLiquidityProxyAdmin" });

    // Deploy the proxy for the collect strategy
    const collectProxy = m.contract("TransparentUpgradeableProxy", [collectStrategy, proxyAdminOwner, collectInit], { id: "StrategiesUniswapV3CollectProxy" });
    const collectProxyAdminAddress = m.readEventArgument(collectProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3CollectAdmin" });
    const collectProxyAdmin = m.contractAt("ProxyAdmin", collectProxyAdminAddress, { id: "StrategiesUniswapV3CollectProxyAdmin" });

    const { manager } = m.useModule(ManagerProxyModule);
    m.call(manager, "setApprovedStrategies", [
        [mintProxy, addBaseTokenOnlyProxy, decreaseLiquidityProxy, zapMintProxy, addLiquidityProxy, collectProxy],
        true
    ])

    // Return the proxies and the corresponding proxy admins
    return {
        mintProxy, mintProxyAdmin,
        addBaseTokenOnlyProxy, addBaseTokenOnlyProxyAdmin,
        decreaseLiquidityProxy, decreaseLiquidityProxyAdmin,
        zapMintProxy, zapMintProxyAdmin,
        addLiquidityProxy, addLiquidityProxyAdmin,
        collectProxy, collectProxyAdmin
    }
});

export default StrategiesUniswapV3Module;