// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Shared.sol";
import {VisionHook} from "../../src/VisionHook.sol";
import {Factory} from "../../src/Factory.sol";

contract FactoryScript is Shared {
    function run(address visionHook) public {
        vm.startBroadcast(deployerPrivateKey);
        console2.log("deploying factory.....");
        Factory factory = new Factory(visionHook, address(swapRouter), posm, poolManager, permit2);
        console2.log("factory", address(factory));
        Factory.DeployVisionFundParams memory params = Factory.DeployVisionFundParams({
            fee: 3000,
            tickSpacing: 60,
            sqrtPriceX96: SQRT_PRICE_1_1,
            name: "test token",
            symbol: "ttoken",
            decimals: 18,
            aiAgent: deployer,
            systemPrompt: "system prompt"
        });

        console2.log("deploying vision fund.....");

        factory.deployVisionFund{value: 0.1 ether}(params);
    }
}
