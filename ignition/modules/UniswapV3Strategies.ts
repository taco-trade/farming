import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export enum Strats {
    mint = 0,
    baseTokenOnly = 1,
    decrease = 2,
}

const StrategiesUniswapV3Module = buildModule("StrategiesUniswapV3Module", (m) => {
    const proxyAdminOwner = m.getAccount(0);

    const addBaseTokenOnlyStrategy = m.contract("UniswapV3StrategyAddBaseTokenOnly")
    // Get the parameters
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const router = m.getParameter("router");


    // Encode the initialize function calls
    const addBaseTokenOnlyInit = m.encodeFunctionCall(addBaseTokenOnlyStrategy, "initialize", [factory, router, positionManager]);

    // Deploy the proxy for the add base token only strategy
    const addBaseTokenOnlyProxy = m.contract("TransparentUpgradeableProxy", [addBaseTokenOnlyStrategy, proxyAdminOwner, addBaseTokenOnlyInit], {id: "StrategiesUniswapV3ABTProxy"});
    const addBaseTokenOnlyProxyAdminAddress = m.readEventArgument(addBaseTokenOnlyProxy, "AdminChanged", "newAdmin", {id: "StrategiesUniswapV3ABTAdmin"});
    const addBaseTokenOnlyProxyAdmin = m.contractAt("ProxyAdmin", addBaseTokenOnlyProxyAdminAddress, {id: "StrategiesUniswapV3ABTProxyAdmin"});

    // Return the proxies and the corresponding proxy admins
    return { addBaseTokenOnlyProxy, addBaseTokenOnlyProxyAdmin }
});

export default StrategiesUniswapV3Module;