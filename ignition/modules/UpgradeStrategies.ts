import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const UpgradeStrategiesModule = buildModule("UpgradeStrategiesModule", (m) => {
    const proxyAdminOwner = m.getAccount(0);
    const addBaseTokenOnlyWithCalculateStrategy = m.contract("UniswapV3StrategyAddBaseTokenOnly", [], {id: "UniswapV3StrategyAddBaseTokenOnly01"})

    // const addBaseTokenOnlyWithCalculateInit = m.encodeFunctionCall(addBaseTokenOnlyWithCalculateStrategy, "initialize", [factory, router, positionManager])
    const proxyAdmin = m.contractAt("ProxyAdmin", "0x733b85D4CBA707d6C26A42fD75B85B6340f488e4")
    const proxy = m.contractAt("TransparentUpgradeableProxy", "0x8cf8e17167F65Ae082399f80eD69472d0Ac28031")

    m.call(proxyAdmin, "upgradeAndCall", [proxy, addBaseTokenOnlyWithCalculateStrategy, "0x"], {
        from: proxyAdminOwner,
    })
    
    // Return the proxies and the corresponding proxy admins
    return { proxyAdmin, proxy }
});

export default UpgradeStrategiesModule;