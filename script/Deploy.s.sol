// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DubbyToken.sol";

contract DeployScript is Script {
    function run() external {
        address taxWallet = vm.envAddress("TAX_WALLET");

        vm.startBroadcast();

        DubbyToken token = new DubbyToken(taxWallet);

        console.log("DubbyToken deployed at:", address(token));
        console.log("Tax wallet set to:", taxWallet);
        console.log("Owner (deployer):", msg.sender);

        vm.stopBroadcast();
    }
}

