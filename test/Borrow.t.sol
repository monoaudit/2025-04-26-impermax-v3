// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {ITokenizedUniswapV3Position} from "../src/interfaces/ITokenizedUniswapV3Position.sol";
import {IBorrowable} from "../src/interfaces/IBorrowable.sol";
import {ICollateral} from "../src/interfaces/ICollateral.sol";
import {IUniswapV3Pool} from "../src/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {LiquidityAmounts} from "../src/libraries/LiquidityAmounts.sol";

contract BorrowTest is Test {
    uint256 baseFork;

    address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address weth = 0x4200000000000000000000000000000000000006;
    address tUniV3Pos = 0xa68F6075ae62eBD514d1600cb5035fa0E2210ef8;
    address imxBusdc = 0xbC303aCdA8B2a0dCD3D17F05aDDdF854eDd6da59;
    address imxCaddr = 0xc1D49fa32d150B31C4a5bf1Cbf23Cf7Ac99eaF7d;
    IERC20 USDC = IERC20(usdc);
    IERC20 WETH = IERC20(weth);
    ITokenizedUniswapV3Position tokenizedUniV3Pos = ITokenizedUniswapV3Position(tUniV3Pos);
    IBorrowable imxBUSDC = IBorrowable(imxBusdc);
    ICollateral imxC = ICollateral(imxCaddr);

    uint24 lowLiquidityPoolFee = 200;

    uint256 usdcLPAmount = 180e6;         // 180 USDC
    uint256 wethLPAmount = 0.1e18;        // 0.1 WETH

    function setUp() public {
        string memory BASE_RPC_URL = vm.envString("BASE_RPC_URL");
        // we will test on the base mainnet fork at specific block
        baseFork = vm.createFork(BASE_RPC_URL, 29437733);
        vm.selectFork(baseFork);
        // provide 180 USDC and 0.1 WETH to the caller
        deal(usdc, address(this), usdcLPAmount);
        deal(weth, address(this), wethLPAmount);
    }

    function test_Borrow() public {
        // choose the pool we want to use
        IUniswapV3Pool pool = IUniswapV3Pool(tokenizedUniV3Pos.getPool(lowLiquidityPoolFee));
        int24 poolTickSpacing = pool.tickSpacing();
        (uint160 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();

        // define the tick range we want to use for LP
        int24 tickLower = int24(int256(tick) * 975 / 1000);
        // align lower tick to tickSpacing
        tickLower = tickLower - (tickLower % poolTickSpacing);

        int24 tickUpper = int24(int256(tick) * 1025 / 1000);
        tickUpper = tickUpper - (tickUpper % poolTickSpacing);
        // in case tickUpper < tickLower, swap them
        if (tickUpper < tickLower) (tickUpper, tickLower) = (tickLower, tickUpper);
        console.log("                tickLower:", tickLower);
        console.log("                tickUpper:", tickUpper);

        // calculate the amount of liquidity we need to provide
        uint128 poolMintAmount = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            wethLPAmount,
            usdcLPAmount
        );
        console.log("           poolMintAmount:", poolMintAmount);

        uint256 usdcBalanceBefore = USDC.balanceOf(address(this));
        uint256 wethBalanceBefore = WETH.balanceOf(address(this));
        console.log("      USDC balance before:", usdcBalanceBefore);
        console.log("      WETH balance before:", wethBalanceBefore);

        // provide liquidity to the pool
        (uint256 wethLProvided, uint256 usdcLProvided) = pool.mint(
            tUniV3Pos,
            tickLower,
            tickUpper,
            poolMintAmount,
            abi.encode(weth, usdc)
        );

        uint256 usdcBalanceAfter = USDC.balanceOf(address(this));
        uint256 wethBalanceAfter = WETH.balanceOf(address(this));
        console.log("      USDC balance  after:", usdcBalanceAfter);
        console.log("      WETH balance  after:", wethBalanceAfter);

        // calculate the amounts provided in terms of USDC
        uint256 currentPrice = ((sqrtPriceX96 * 1e18 / 2**96) ** 2) / 1e18;
        uint256 wethUsdcProvided = (currentPrice * wethLProvided) / 1e18;
        console.log("            WETH provided:", wethUsdcProvided);
        console.log("            USDC provided:", usdcLProvided);
        uint256 totalUsdcProvided = usdcLProvided + wethUsdcProvided;
        console.log("           Total provided:", totalUsdcProvided);

        // mint the tokenized position
        uint256 tokenId = tokenizedUniV3Pos.mint(
            address(this),
            lowLiquidityPoolFee,
            tickLower,
            tickUpper
        );

        // transfer the tokenized position to the IMX contract
        tokenizedUniV3Pos.transferFrom(address(this), imxCaddr, tokenId);

        // minting the collateral
        imxC.mint(address(this), tokenId);

        // define the borrow amount as 75% of the total USDC provided
        uint256 toBorrow = (totalUsdcProvided * 75) / 100;

        // borrow USDC against the collateral
        imxBUSDC.borrow(tokenId, address(this), toBorrow, "");

        uint256 usdcBalanceAfterBorrow = USDC.balanceOf(address(this));
        uint256 wethBalanceAfterBorrow = WETH.balanceOf(address(this));
        console.log("USDC balance after borrow:", usdcBalanceAfterBorrow);
        console.log("WETH balance after borrow:", wethBalanceAfterBorrow);

        // check that we have borrowed the correct amount of USDC
        assertGe(usdcBalanceAfterBorrow, usdcBalanceAfter + toBorrow);
    }

    function uniswapV3MintCallback(
        uint256 amount0Delta,
        uint256 amount1Delta,
        bytes calldata data
    ) public {
        (address token0, address token1) = abi.decode(data, (address, address));
        
        if (amount0Delta > 0) {
            IERC20(token0).transfer(msg.sender, amount0Delta);
        }
        if (amount1Delta > 0) {
            IERC20(token1).transfer(msg.sender, amount1Delta);
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

}
