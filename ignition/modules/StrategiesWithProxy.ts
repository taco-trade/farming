import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const StrategiesWithProxyModule = buildModule("StrategiesWithProxyModule", (m) => {
    const proxyAdminOwner = m.getAccount(0);

    // Deploy the strategies implementations
    const mintStrategy = m.contract("PancakeSwapV3Mint");
    const decreaseLiquidityStrategy = m.contract("PancakeSwapV3DecreaseLiquidity");
    const addBaseTokenOnlyStrategy = m.contract("PancakeswapV3StrategyAddBaseTokenOnly");
    const addBaseTokenOnlyWithCalculateStrategy = m.contract("PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate");

    // Get the parameters
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const router = m.getParameter("router");

    // Encode the initialize function calls
    const mintInit = m.encodeFunctionCall(mintStrategy, "initialize", [positionManager]);
    const decreaseLiquidityInit = m.encodeFunctionCall(decreaseLiquidityStrategy, "initialize", [positionManager]);
    const addBaseTokenOnlyInit = m.encodeFunctionCall(addBaseTokenOnlyStrategy, "initialize", [factory, router, positionManager]);
    const addBaseTokenOnlyWithCalculateInit = m.encodeFunctionCall(addBaseTokenOnlyWithCalculateStrategy, "initialize", [factory, router, positionManager]);

    // Deploy the proxy for the mint strategy
    const mintProxy = m.contract("TransparentUpgradeableProxy", [mintStrategy, proxyAdminOwner, mintInit], {id: "StrategiesMintProxy"});
    const mintProxyAdminAddress = m.readEventArgument(mintProxy, "AdminChanged", "newAdmin", {id: "StrategiesMintAdmin"});
    const mintProxyAdmin = m.contractAt("ProxyAdmin", mintProxyAdminAddress, {id: "StrategiesMintProxyAdmin"});

    // Deploy the proxy for the decrease liquidity strategy
    const decreaseLiquidityProxy = m.contract("TransparentUpgradeableProxy", [decreaseLiquidityStrategy, proxyAdminOwner, decreaseLiquidityInit], {id: "StrategiesDecProxy"});
    const decreaseLiquidityProxyAdminAddress = m.readEventArgument(decreaseLiquidityProxy, "AdminChanged", "newAdmin", {id: "StrategiesDecAdmin"});
    const decreaseLiquidityProxyAdmin = m.contractAt("ProxyAdmin", decreaseLiquidityProxyAdminAddress, {id: "StrategiesDecProxyAdmin"});

    // Deploy the proxy for the add base token only strategy
    const addBaseTokenOnlyProxy = m.contract("TransparentUpgradeableProxy", [addBaseTokenOnlyStrategy, proxyAdminOwner, addBaseTokenOnlyInit], {id: "StrategiesABTProxy"});
    const addBaseTokenOnlyProxyAdminAddress = m.readEventArgument(addBaseTokenOnlyProxy, "AdminChanged", "newAdmin", {id: "StrategiesABTAdmin"});
    const addBaseTokenOnlyProxyAdmin = m.contractAt("ProxyAdmin", addBaseTokenOnlyProxyAdminAddress, {id: "StrategiesABTProxyAdmin"});

    // Deploy the proxy for the add base token only with calculate strategy
    const addBaseTokenOnlyWithCalculateProxy = m.contract("TransparentUpgradeableProxy", [addBaseTokenOnlyWithCalculateStrategy, proxyAdminOwner, addBaseTokenOnlyWithCalculateInit], {id: "StrategiesABTWCProxy"});
    const addBaseTokenOnlyWithCalculateProxyAdminAddress = m.readEventArgument(addBaseTokenOnlyWithCalculateProxy, "AdminChanged", "newAdmin", {id: "StrategiesABTWCAdmin"});
    const addBaseTokenOnlyWithCalculateProxyAdmin = m.contractAt("ProxyAdmin", addBaseTokenOnlyWithCalculateProxyAdminAddress, {id: "StrategiesABTWCProxyAdmin"});

    // Return the proxies and the corresponding proxy admins
    return { mintProxy, mintProxyAdmin, decreaseLiquidityProxy, decreaseLiquidityProxyAdmin, addBaseTokenOnlyProxy, addBaseTokenOnlyProxyAdmin, addBaseTokenOnlyWithCalculateProxy, addBaseTokenOnlyWithCalculateProxyAdmin }
});

export default StrategiesWithProxyModule;