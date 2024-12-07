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
import "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

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

        uint256 ethAmount = 0.1 ether;
        // https://blog.uniswap.org/uniswap-v3-math-primer
        // price = token1/token0 = 500/0.1 = 5000
        // sqrtPriceX96 = floor(sqrt(A / B) * 2 ** 96) where A and B are the currency reserves
        // sqrtPriceX96=floor(sqrt(5000)*2^96)=5602277097478613991873193822745  (https://www.wolframalpha.com/input?i=floor%28sqrt%285000%29*2%5E96%29)
        // price- ticker converter https://uniswaphooks.com/tool/tick-price
        // let tick = Math.floor(Math.log((sqrtPriceX96/Q96)**2)/Math.log(1.0001));
        uint160 sqrtPriceX96 = 5602277097478613991873193822745; // 500/0.1 - {5}
        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        console.log("tick", tick);

        uint160 sqrtPriceAX96 = 3543190000000000000000000000000; // 200/0.1 - {40}
        int24 tickA = TickMath.getTickAtSqrtPrice(sqrtPriceAX96);

        uint160 sqrtPriceBX96 = 6136987079367210512574055639355; // 600/0.1
        int24 tickB = TickMath.getTickAtSqrtPrice(sqrtPriceBX96);
        console2.log("tick for price 0.1-500", tick);

        Factory.DeployVisionFundParams memory params = Factory.DeployVisionFundParams({
            fee: 3000,
            tickSpacing: 60,
            sqrtPriceX96: sqrtPriceX96,
            name: "test token",
            symbol: "ttoken",
            decimals: 18,
            aiAgent: user,
            systemPrompt: "prompt"
        });

        (PoolKey memory poolKey, address action, address tokenAddr) = factory.deployVisionFund{value: ethAmount}(params);

        // test add liquidity
        // 1.buy token first
        // BalanceDelta delta = swapRouter.swap{value: 0.002 ether}(
        //     poolKey,
        //     IPoolManager.SwapParams({
        //         zeroForOne: true,
        //         amountSpecified: -0.002 ether, // Exact input for output swap
        //         sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        //     }),
        //     PoolSwapTest.TestSettings({takeClaims: true, settleUsingBurn: false}),
        //     ""
        // );
        // console2.log("balance delta token0", delta.amount0());
        // console2.log("balance delta token1", delta.amount1());
        // console2.log("token balance", IERC20(tokenAddr).balanceOf(address(this)));
        // IERC20(tokenAddr).approve(address(hook), type(uint256).max);
        // 2. add single side liquidity with 0.001 ether
        int24 tickMin = TickMath.minUsableTick(60);
        int24 tickMax = TickMath.maxUsableTick(60);

        // int24 tickUpper =
        // int24 tickUpper_ = TickMath.getTickAtSqrtPrice(792281625142643375935439503360000); // 1000/0.1

        (uint160 currentSqrtPriceX96, int24 currentTick,,) = manager.getSlot0(key.toId());

        uint256 amount0 = 0.01 ether;
        uint128 singleSideLiquditity =
            LiquidityAmounts.getLiquidityForAmount0(currentSqrtPriceX96, sqrtPriceBX96, amount0);
        console2.log("singleSideLiquditity", singleSideLiquditity);

        uint256 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            currentSqrtPriceX96, TickMath.getSqrtPriceAtTick(tickB), TickMath.getSqrtPriceAtTick(tickMax), amount0, 0
        );

        console2.log("liquidity", liquidity);

        hook.AddLiquidity{value: amount0}(
            poolKey,
            VisionHook.AddLiquidityParams({
                tickLower: tickB + 1, // add 1 to fit the tick spacing
                tickUpper: tickMax,
                amount0Desired: amount0,
                amount1Desired: 0,
                deadline: block.timestamp
            }),
            "hello"
        );
    }

    function testFactory_ethNeededForLiquidity() public {
        factory = new Factory(address(hook), address(swapRouter), posm, manager, permit2);

        uint256 ethAmount = 0.1 ether;
        // https://blog.uniswap.org/uniswap-v3-math-primer
        // price = token1/token0 = 500/0.1 = 5000
        // sqrtPriceX96 = floor(sqrt(A / B) * 2 ** 96) where A and B are the currency reserves
        // sqrtPriceX96=floor(sqrt(5000)*2^96)=5602277097478613991873193822745  (https://www.wolframalpha.com/input?i=floor%28sqrt%285000%29*2%5E96%29)
        // price- ticker converter https://uniswaphooks.com/tool/tick-price
        uint160 sqrtPriceX96 = 5602277097478613991873193822745;
        // int24 tick = TickMath.getTickAtSqrtPrice(5602277097478613991873193822745);
        // console2.log("tick for price 0.1-500", tick);
        uint256 expectedEth = factory.ethNeededForLiquidity(60, sqrtPriceX96);
        assertApproxEqAbs(ethAmount, expectedEth, 100);
    }
}
