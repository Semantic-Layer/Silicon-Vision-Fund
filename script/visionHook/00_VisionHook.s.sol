// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol"; // not for production

import {HookMiner} from "../../test/utils/HookMiner.sol";

import {VisionHook} from "../../src/VisionHook.sol";
import {Factory} from "../../src/Factory.sol";

contract VisionHookScrpipt is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    uint256 constant MAX_DEADLINE = 12329839823;
    uint256 constant SEPOLIA_CHAINID = 11155111;
    uint256 constant UNICHAIN_CHAINID = 1301;

    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address internal deployer = vm.addr(deployerPrivateKey);

    IPoolManager poolManager;
    IPositionManager posm;
    IAllowanceTransfer permit2;
    PoolSwapTest swapRouter;

    function setUp() public {
        assignUniv4Address();
    }

    function run() public {
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG);

        bytes memory constructorArgs = abi.encode(poolManager, address(posm), address(permit2));

        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(VisionHook).creationCode, constructorArgs);

        vm.startBroadcast(deployerPrivateKey);
        VisionHook visionHook = new VisionHook{salt: salt}(poolManager, payable(address(posm)), address(permit2));

        require(address(visionHook) == hookAddress, "VisionHookScrpipt: hook address mismatch");
    }

    function assignUniv4Address() public {
        uint256 chainId = block.chainid;
        if (chainId == SEPOLIA_CHAINID) {
            console2.log("deploying on sepolia");
            poolManager = IPoolManager(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A);
            posm = IPositionManager(0x1B1C77B606d13b09C84d1c7394B96b147bC03147);
            swapRouter = PoolSwapTest(0xe49d2815C231826caB58017e214Bed19fE1c2dD4);
            permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        } else if (chainId == UNICHAIN_CHAINID) {
            console2.log("deploying on unichain sepolia");
            poolManager = IPoolManager(0xC81462Fec8B23319F288047f8A03A57682a35C1A);
            posm = IPositionManager(0xB433cB9BcDF4CfCC5cAB7D34f90d1a7deEfD27b9);
            swapRouter = PoolSwapTest(0xe437355299114d35Ffcbc0c39e163B24A8E9cBf1);
            permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        } else {
            revert("chain not supported");
        }
    }
}
