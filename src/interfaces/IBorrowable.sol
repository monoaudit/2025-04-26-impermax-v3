// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IBorrowable {
    /**
     * Impermax ERC20 **
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /**
     * Pool Token **
     */
    event Mint(address indexed sender, address indexed minter, uint256 mintAmount, uint256 mintTokens);
    event Redeem(address indexed sender, address indexed redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event Sync(uint256 totalBalance);

    function underlying() external view returns (address);
    function factory() external view returns (address);
    function totalBalance() external view returns (uint256);
    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function exchangeRate() external returns (uint256);
    function mint(address minter) external returns (uint256 mintTokens);
    function redeem(address redeemer) external returns (uint256 redeemAmount);
    function skim(address to) external;
    function sync() external;

    function _setFactory() external;

    /**
     * Borrowable **
     */
    event BorrowApproval(address indexed owner, address indexed spender, uint256 value);
    event Borrow(
        address indexed sender,
        uint256 indexed tokenId,
        address indexed receiver,
        uint256 borrowAmount,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event Liquidate(
        address indexed sender,
        uint256 indexed tokenId,
        address indexed liquidator,
        uint256 seizeTokenId,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event RestructureDebt(
        uint256 indexed tokenId,
        uint256 reduceToRatio,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );

    function collateral() external view returns (address);
    function reserveFactor() external view returns (uint256);
    function exchangeRateLast() external view returns (uint256);
    function borrowIndex() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function borrowAllowance(address owner, address spender) external view returns (uint256);
    function borrowBalance(uint256 tokenId) external view returns (uint256);
    function currentBorrowBalance(uint256 tokenId) external returns (uint256);

    function BORROW_PERMIT_TYPEHASH() external pure returns (bytes32);
    function borrowApprove(address spender, uint256 value) external returns (bool);
    function borrowPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function borrow(uint256 tokenId, address receiver, uint256 borrowAmount, bytes calldata data) external;
    function liquidate(uint256 tokenId, uint256 repayAmount, address liquidator, bytes calldata data)
        external
        returns (uint256 seizeTokenId);
    function restructureDebt(uint256 tokenId, uint256 reduceToRatio) external;

    /**
     * Borrowable Interest Rate Model **
     */
    event AccrueInterest(uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event CalculateKink(uint256 kinkRate);
    event CalculateBorrowRate(uint256 borrowRate);

    function KINK_BORROW_RATE_MAX() external pure returns (uint256);
    function KINK_BORROW_RATE_MIN() external pure returns (uint256);
    function KINK_MULTIPLIER() external pure returns (uint256);
    function borrowRate() external view returns (uint256);
    function kinkBorrowRate() external view returns (uint256);
    function kinkUtilizationRate() external view returns (uint256);
    function adjustSpeed() external view returns (uint256);
    function rateUpdateTimestamp() external view returns (uint32);
    function accrualTimestamp() external view returns (uint32);

    function accrueInterest() external;

    /**
     * Borrowable Setter **
     */
    event NewReserveFactor(uint256 newReserveFactor);
    event NewKinkUtilizationRate(uint256 newKinkUtilizationRate);
    event NewAdjustSpeed(uint256 newAdjustSpeed);
    event NewDebtCeiling(uint256 newDebtCeiling);

    function RESERVE_FACTOR_MAX() external pure returns (uint256);
    function KINK_UR_MIN() external pure returns (uint256);
    function KINK_UR_MAX() external pure returns (uint256);
    function ADJUST_SPEED_MIN() external pure returns (uint256);
    function ADJUST_SPEED_MAX() external pure returns (uint256);

    function _initialize(string calldata _name, string calldata _symbol, address _underlying, address _collateral)
        external;
    function _setReserveFactor(uint256 newReserveFactor) external;
    function _setKinkUtilizationRate(uint256 newKinkUtilizationRate) external;
    function _setAdjustSpeed(uint256 newAdjustSpeed) external;
}
