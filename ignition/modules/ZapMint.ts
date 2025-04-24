import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ManagerProxyModule from "./ManagerWithProxy";

const ZapMintModule = buildModule("ZapMintModule", (m) => {
    const proxyAdminOwner = m.getAccount(0);

    const zapMintStrategy = m.contract("UniswapV3ZapMint")

    // Get the parameters
    const positionManager = m.getParameter("positionManager");
    const factory = m.getParameter("factory");
    const router = m.getParameter("router");

    // Encode the initialize function calls
    const zapMintInit = m.encodeFunctionCall(zapMintStrategy, "initialize", [factory, router, positionManager]);

    // Deploy the proxy for the zap mint strategy
    const zapMintProxy = m.contract("TransparentUpgradeableProxy", [zapMintStrategy, proxyAdminOwner, zapMintInit], { id: "StrategiesUniswapV3ZapMintProxy" });
    const zapMintProxyAdminAddress = m.readEventArgument(zapMintProxy, "AdminChanged", "newAdmin", { id: "StrategiesUniswapV3ZapMintAdmin" });
    const zapMintProxyAdmin = m.contractAt("ProxyAdmin", zapMintProxyAdminAddress, { id: "StrategiesUniswapV3ZapMintProxyAdmin" });

    const managerAddress = "0x808e5bE958Ea75f9248CC2a60b03887B52b3D71A";
    const manager = m.contractAt("Manager", managerAddress, { id: "Manager" });
    m.call(manager, "setApprovedStrategies", [
        [zapMintProxy],
        true
    ])
    // Return the proxies and the corresponding proxy admins
    return { zapMintProxy, zapMintProxyAdmin }
});

export default ZapMintModule;