// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {VisionHook} from "../src/VisionHook.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/src/tokens/ERC721.sol";
import {Factory} from "../src/Factory.sol";

contract VisionHookTest is Test, Fixtures, ERC721TokenReceiver {
    using SafeCast for uint256;
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    uint256 constant MAX_DEADLINE = 12329839823;

    uint256 internal userPrivateKey = 0xad111;
    address internal user = vm.addr(userPrivateKey);

    VisionHook hook;
    PoolId poolId;

    Factory factory;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        vm.label(user, "user");
        // vm.startPrank(user);
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager, address(posm), address(permit2)); //Add all the necessary constructor arguments from the hook
        deployCodeTo("VisionHook.sol:VisionHook", constructorArgs, flags);
        hook = VisionHook(flags);

        // approve hook
        IERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        // Create the pool

        (key, poolId) =
            initPoolAndAddLiquidityETH(Currency.wrap(address(0)), currency1, hook, 3000, SQRT_PRICE_1_1, 1 ether);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        console2.log("amount 0 ", amount0Expected);
        console2.log("amount 1 ", amount1Expected);

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        // BalanceDelta addedDelta = modifyLiquidityNoChecks.modifyLiquidity{value: amount0Expected+1}(
        //     key,
        //     IPoolManager.ModifyLiquidityParams({
        //         tickLower: tickLower,
        //         tickUpper: tickUpper,
        //         liquidityDelta: (uint256(liquidityAmount)).toInt256(),
        //         salt: 0
        //     }),
        //     ""
        // );

        // vm.stopPrank();
    }

    // function testReceiveLPNFT() public {
    //     ERC721(address(posm)).safeTransferFrom(address(this), address(hook), 1);
    // }

    function testAddliquidity() public {
        console2.log("balance", address(this).balance);
        // vm.startPrank(user);

        // // Provide full-range liquidity to the pool
        //     tickLower = TickMath.minUsableTick(key.tickSpacing);
        //     tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 1e18;

        uint256 beforeNFTbalanace = hook.balanceOf(address(this));

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        console2.log("amount 0 k ", amount0Expected);
        console2.log("amount 1 k ", amount1Expected);

        currency1.transfer(address(hook), 100000);

        hook.AddLiquidity{value: amount0Expected}(
            key,
            VisionHook.AddLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Expected,
                amount1Desired: amount1Expected,
                deadline: MAX_DEADLINE
            }),
            bytes("hello")
        );

        // check nft balance
        uint256 afterNFTbalanace = hook.balanceOf(address(this));

        assertEq(afterNFTbalanace - beforeNFTbalanace, 1);

        assertEq(ERC721(address(posm)).balanceOf(address(hook)), 1);

        vm.expectRevert();
        hook.redeemLP(1);
        vm.warp(block.timestamp + 1 + 1 days);

        hook.redeemLP(1);

        assertEq(hook.balanceOf(address(this)), 0);
        assertEq(ERC721(address(posm)).balanceOf(address(this)), 2);
    }

    function testFactory() public {
        factory = new Factory(address(hook), address(swapRouter), posm, manager, permit2);

        
    }
}
