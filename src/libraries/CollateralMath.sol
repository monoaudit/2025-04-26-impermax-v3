// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "../interfaces/INFTLP.sol";

library CollateralMath {
    using SafeMath for uint256;

    uint256 constant Q64 = 2 ** 64;
    uint256 constant Q96 = 2 ** 96;
    uint256 constant Q192 = 2 ** 192;

    enum Price {
        LOWEST,
        CURRENT,
        HIGHEST
    }

    struct PositionObject {
        INFTLP.RealXYs realXYs;
        uint256 priceSqrtX96;
        uint256 debtX;
        uint256 debtY;
        uint256 liquidationPenalty;
        uint256 safetyMarginSqrt;
    }

    function newPosition(
        INFTLP.RealXYs memory realXYs,
        uint256 priceSqrtX96,
        uint256 debtX,
        uint256 debtY,
        uint256 liquidationPenalty,
        uint256 safetyMarginSqrt
    ) internal pure returns (PositionObject memory) {
        return PositionObject({
            realXYs: realXYs,
            priceSqrtX96: priceSqrtX96,
            debtX: debtX,
            debtY: debtY,
            liquidationPenalty: liquidationPenalty,
            safetyMarginSqrt: safetyMarginSqrt
        });
    }

    function safeInt256(uint256 n) internal pure returns (int256) {
        require(n < 2 ** 255, "Impermax: SAFE_INT");
        return int256(n);
    }

    // reversed from getValue
    function getDebtY(PositionObject memory positionObject, Price price, uint256 amountX, uint256 debtValue)
        internal
        pure
        returns (uint256)
    {
        uint256 priceSqrtX96 = positionObject.priceSqrtX96;
        if (price == Price.LOWEST) priceSqrtX96 = priceSqrtX96.mul(1e18).div(positionObject.safetyMarginSqrt);
        if (price == Price.HIGHEST) priceSqrtX96 = priceSqrtX96.mul(positionObject.safetyMarginSqrt).div(1e18);
        uint256 relativePriceX = getRelativePriceX(priceSqrtX96);
        uint256 relativePriceY = getRelativePriceY(priceSqrtX96);
        uint256 debtY = debtValue.mul(Q64).div(relativePriceY).sub(amountX.mul(relativePriceX).div(Q64));
        return debtY;
    }

    // price
    function getRelativePriceX(uint256 priceSqrtX96) internal pure returns (uint256) {
        return priceSqrtX96;
    }
    // 1 / price

    function getRelativePriceY(uint256 priceSqrtX96) internal pure returns (uint256) {
        return Q192.div(priceSqrtX96);
    }

    // amountX * priceX + amountY * priceY
    function getValue(PositionObject memory positionObject, Price price, uint256 amountX, uint256 amountY)
        internal
        pure
        returns (uint256)
    {
        uint256 priceSqrtX96 = positionObject.priceSqrtX96;
        if (price == Price.LOWEST) priceSqrtX96 = priceSqrtX96.mul(1e18).div(positionObject.safetyMarginSqrt);
        if (price == Price.HIGHEST) priceSqrtX96 = priceSqrtX96.mul(positionObject.safetyMarginSqrt).div(1e18);
        uint256 relativePriceX = getRelativePriceX(priceSqrtX96);
        uint256 relativePriceY = getRelativePriceY(priceSqrtX96);
        return amountX.mul(relativePriceX).div(Q64).add(amountY.mul(relativePriceY).div(Q64));
    }

    // realX * priceX + realY * priceY
    function getCollateralValue(PositionObject memory positionObject, Price price) internal pure returns (uint256) {
        INFTLP.RealXY memory realXY = positionObject.realXYs.currentPrice;
        if (price == Price.LOWEST) realXY = positionObject.realXYs.lowestPrice;
        if (price == Price.HIGHEST) realXY = positionObject.realXYs.highestPrice;
        return getValue(positionObject, price, realXY.realX, realXY.realY);
    }

    // debtX * priceX + realY * debtY
    function getDebtValue(PositionObject memory positionObject, Price price) internal pure returns (uint256) {
        return getValue(positionObject, price, positionObject.debtX, positionObject.debtY);
    }

    // collateralValue - debtValue * liquidationPenalty
    function getLiquidityPostLiquidation(PositionObject memory positionObject, Price price)
        internal
        pure
        returns (int256)
    {
        uint256 collateralNeeded = getDebtValue(positionObject, price).mul(positionObject.liquidationPenalty).div(1e18);
        uint256 collateralValue = getCollateralValue(positionObject, price);
        return safeInt256(collateralValue) - safeInt256(collateralNeeded);
    }

    // collateralValue / (debtValue * liquidationPenalty)
    function getPostLiquidationCollateralRatio(PositionObject memory positionObject) internal pure returns (uint256) {
        uint256 collateralNeeded =
            getDebtValue(positionObject, Price.CURRENT).mul(positionObject.liquidationPenalty).div(1e18);
        uint256 collateralValue = getCollateralValue(positionObject, Price.CURRENT);
        return collateralValue.mul(1e18).div(collateralNeeded, "ImpermaxV3Collateral: NO_DEBT");
    }

    function isLiquidatable(PositionObject memory positionObject) internal pure returns (bool) {
        int256 a = getLiquidityPostLiquidation(positionObject, Price.LOWEST);
        int256 b = getLiquidityPostLiquidation(positionObject, Price.HIGHEST);
        return a < 0 || b < 0;
    }

    function isUnderwater(PositionObject memory positionObject) internal pure returns (bool) {
        int256 liquidity = getLiquidityPostLiquidation(positionObject, Price.CURRENT);
        return liquidity < 0;
    }
}
