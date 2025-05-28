// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ICollateral {
    /* ImpermaxERC721 */

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /* Collateral */

    event Mint(address indexed to, uint256 tokenId);
    event Redeem(address indexed to, uint256 tokenId, uint256 percentage, uint256 redeemTokenId);
    event Seize(address indexed to, uint256 tokenId, uint256 percentage, uint256 redeemTokenId);
    event RestructureBadDebt(uint256 tokenId, uint256 postLiquidationCollateralRatio);

    function underlying() external view returns (address);
    function factory() external view returns (address);
    function borrowable0() external view returns (address);
    function borrowable1() external view returns (address);
    function safetyMarginSqrt() external view returns (uint256);
    function liquidationIncentive() external view returns (uint256);
    function liquidationFee() external view returns (uint256);
    function liquidationPenalty() external view returns (uint256);

    function mint(address to, uint256 tokenId) external;
    function redeem(address to, uint256 tokenId, uint256 percentage, bytes calldata data)
        external
        returns (uint256 redeemTokenId);
    function redeem(address to, uint256 tokenId, uint256 percentage) external returns (uint256 redeemTokenId);
    function isLiquidatable(uint256 tokenId) external returns (bool);
    function isUnderwater(uint256 tokenId) external returns (bool);
    function canBorrow(uint256 tokenId, address borrowable, uint256 accountBorrows) external returns (bool);
    function restructureBadDebt(uint256 tokenId) external;
    function seize(uint256 tokenId, uint256 repayAmount, address liquidator, bytes calldata data)
        external
        returns (uint256 seizeTokenId);

    /* CSetter */

    event NewSafetyMargin(uint256 newSafetyMarginSqrt);
    event NewLiquidationIncentive(uint256 newLiquidationIncentive);
    event NewLiquidationFee(uint256 newLiquidationFee);

    function SAFETY_MARGIN_SQRT_MIN() external pure returns (uint256);
    function SAFETY_MARGIN_SQRT_MAX() external pure returns (uint256);
    function LIQUIDATION_INCENTIVE_MIN() external pure returns (uint256);
    function LIQUIDATION_INCENTIVE_MAX() external pure returns (uint256);
    function LIQUIDATION_FEE_MAX() external pure returns (uint256);

    function _setFactory() external;
    function _initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _borrowable0,
        address _borrowable1
    ) external;
    function _setSafetyMarginSqrt(uint256 newSafetyMarginSqrt) external;
    function _setLiquidationIncentive(uint256 newLiquidationIncentive) external;
    function _setLiquidationFee(uint256 newLiquidationFee) external;
}
