// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {INFTLP} from "./INFTLP.sol";

interface ITokenizedUniswapV3Position {
	
	// ERC-721
	
	function name() external view returns (string memory);
	function symbol() external view returns (string memory);
	function balanceOf(address owner) external view returns (uint256 balance);
	function ownerOf(uint256 tokenId) external view returns (address owner);
	function getApproved(uint256 tokenId) external view returns (address operator);
	function isApprovedForAll(address owner, address operator) external view returns (bool);
	
	function DOMAIN_SEPARATOR() external view returns (bytes32);
	function nonces(uint256 tokenId) external view returns (uint256);
	
	function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
	function safeTransferFrom(address from, address to, uint256 tokenId) external;
	function transferFrom(address from, address to, uint256 tokenId) external;
	function approve(address to, uint256 tokenId) external;
	function setApprovalForAll(address operator, bool approved) external;
	function permit(address spender, uint tokenId, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
	
	// INFTLP
	
	function token0() external view returns (address);
	function token1() external view returns (address);
	function getPositionData(uint256 _tokenId, uint256 _safetyMarginSqrt) external returns (
		uint256 priceSqrtX96,
		INFTLP.RealXYs memory realXYs
	);
	
	function join(uint256 tokenId, uint256 tokenToJoin) external;
	function split(uint256 tokenId, uint256 percentage) external returns (uint256 newTokenId);
	
	// ITokenizedUniswapV3Position
	
	struct Position {
		uint24 fee;
		int24 tickLower;
		int24 tickUpper;
		uint128 liquidity;
		uint256 feeGrowthInside0LastX128;
		uint256 feeGrowthInside1LastX128;
		uint256 unclaimedFees0;	
		uint256 unclaimedFees1;	
	}
	
	function factory() external view returns (address);
	function uniswapV3Factory() external view returns (address);
	
	function totalBalance(uint24 fee, int24 tickLower, int24 tickUpper) external view returns (uint256);
	
	function positions(uint256 tokenId) external view returns (
		uint24 fee,
		int24 tickLower,
		int24 tickUpper,
		uint128 liquidity,
		uint256 feeGrowthInside0LastX128,
		uint256 feeGrowthInside1LastX128,
		uint256 unclaimedFees0,
		uint256 unclaimedFees1
	);
	function positionsLength() external view returns (uint256);
	
	function getPool(uint24 fee) external view returns (address pool);
	
	function oraclePriceSqrtX96() external returns (uint256);
	
	event MintPosition(uint256 indexed tokenId, uint24 fee, int24 tickLower, int24 tickUpper);
	event UpdatePositionLiquidity(uint256 indexed tokenId, uint256 liquidity);
	event UpdatePositionFeeGrowthInside(uint256 indexed tokenId, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128);
	event UpdatePositionUnclaimedFees(uint256 indexed tokenId, uint256 unclaimedFees0, uint256 unclaimedFees1);

	function _initialize (
		address _uniswapV3Factory, 
		address _oracle, 
		address _token0, 
		address _token1
	) external;
	
	function mint(address to, uint24 fee, int24 tickLower, int24 tickUpper) external  returns (uint256 newTokenId);
	function redeem(address to, uint256 tokenId) external  returns (uint256 amount0, uint256 amount1);

}
