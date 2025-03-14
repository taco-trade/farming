// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

library EnvConfig {

    function useBscTestnet(Vm vm) internal {
        string memory BSCTESTNET_RPC_URL = vm.envString("BSC_TESTNET_RPC");
        uint256 bsctestnetFork = vm.createFork(BSCTESTNET_RPC_URL);
        vm.selectFork(bsctestnetFork);
    }
}
