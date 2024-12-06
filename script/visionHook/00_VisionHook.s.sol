// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HookMiner} from "../../test/utils/HookMiner.sol";

import {VisionHook} from "../../src/VisionHook.sol";
import {Factory} from "../../src/Factory.sol";
import "./Shared.sol";

contract VisionHookScrpipt is Shared {
    function run() public {
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG);

        bytes memory constructorArgs = abi.encode(poolManager, address(posm), address(permit2));

        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(VisionHook).creationCode, constructorArgs);

        vm.startBroadcast(deployerPrivateKey);
        VisionHook visionHook = new VisionHook{salt: salt}(poolManager, payable(address(posm)), address(permit2));

        require(address(visionHook) == hookAddress, "VisionHookScrpipt: hook address mismatch");
    }
}
