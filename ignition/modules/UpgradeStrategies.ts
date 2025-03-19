import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import StrategiesWithProxyModule from "./StrategiesWithProxy";


const UpgradeStrategiesModule = buildModule("UpgradeStrategiesModule", (m) => {
    const proxyAdminOwner = m.getAccount(0);

    const { addBaseTokenOnlyWithCalculateProxyAdmin, addBaseTokenOnlyWithCalculateProxy } = m.useModule(StrategiesWithProxyModule)

    const addBaseTokenOnlyWithCalculateStrategy = m.contract("PancakeswapV3StrategyAddBaseTokenOnlyWithCalculate", [], {id: "addBaseTokenOnlyWithCalculateStrategyV2"})

    // Get the parameters
    const positionManager = m.getParameter("positionManager")
    const factory = m.getParameter("factory")
    const router = m.getParameter("router")

    const addBaseTokenOnlyWithCalculateInit = m.encodeFunctionCall(addBaseTokenOnlyWithCalculateStrategy, "initialize", [factory, router, positionManager])

    m.call(addBaseTokenOnlyWithCalculateProxyAdmin, "upgradeAndCall", [addBaseTokenOnlyWithCalculateProxy, addBaseTokenOnlyWithCalculateStrategy, addBaseTokenOnlyWithCalculateInit], {
        from: proxyAdminOwner,
    })
    
    // Return the proxies and the corresponding proxy admins
    return { addBaseTokenOnlyWithCalculateProxy, addBaseTokenOnlyWithCalculateProxyAdmin }
});

export default UpgradeStrategiesModule;