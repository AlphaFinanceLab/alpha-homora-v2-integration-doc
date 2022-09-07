// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC1155/IERC1155.sol";
import "./IUniswapV3PositionManager.sol";
import "../../IGovernable.sol";

interface IWUniswapV3Position is IERC1155, IGovernable {
  struct PositionInfo {
    uint256 uniV3PositionManagerId;
    address pool;
    address bene;
    address token0;
    address token1;
    uint24 fee;
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
  }

  /// @dev ERC1155 token/uniV3 position ID => positionInfo
  /// @param _uniV3PositionId uniswap v3 position id
  /// @return info uniswap v3 position info
  function positions(uint256 _uniV3PositionId)
    external
    view
    returns (PositionInfo memory info);

  /// @dev get uniswap v3 position manager
  function positionManager()
    external
    view
    returns (IUniswapV3PositionManager positionManager);

  /// @dev Return the underlying pool for the given ERC1155 token id.
  /// @param _tokenId ERC1155 Token id
  /// @return pool uniV3 pool address
  function getUnderlyingToken(uint256 _tokenId)
    external
    view
    returns (address pool);

  /// @dev Return the conversion rate from ERC1155 to the UniV3position, multiplied by 2**112.
  function getUnderlyingRate(uint256) external returns (uint256);

  /// @dev get uniswap v3 position info from token id
  function getPositionInfoFromTokenId(uint256 _tokenId)
    external
    view
    returns (PositionInfo memory info);

  /// @dev transfer position into this contract and mint ERC1155 to the caller with the amount of
  /// the liquidity being added into the position.
  /// @param _uniV3PositionManagerId position id from UniV3's nonfungible position manager.
  /// @param _bene the one who receive fee from providing liquidity.
  /// @return id ERC1155 tokenId.
  /// @return amount The amount of ERC1155 being minted.
  function mint(uint256 _uniV3PositionManagerId, address _bene)
    external
    returns (uint256 id, uint256 amount);

  /// @dev mint ERC1155 to the caller with the amount of the liquidity being added into the position.
  /// @param _tokenId ERC1155 tokenId.
  /// @return id ERC1155 tokenId.
  /// @return amount The amount of ERC1155 being minted.
  function sync(uint256 _tokenId) external returns (uint256 id, uint256 amount);

  /// @dev burn ERC1155 and removeLiquidity from the position.
  /// @param _tokenId ERC1155 tokenId.
  /// @param _amount amount of token being burnt.
  /// @param _amount0Min minimum expected amount of token0.
  /// @param _amount1Min minimum expected amount of token1.
  /// @param _deadline deadline for decreaseLiquidity.
  /// @return amount0 The amount of token0 sent to the recipient.
  /// @return amount1 The amount of token1 sent to the recipient.
  function burn(
    uint256 _tokenId,
    uint256 _amount,
    uint256 _amount0Min,
    uint256 _amount1Min,
    uint256 _deadline
  ) external returns (uint256 amount0, uint256 amount1);

  /// @dev Transfer fee to beneficiary of the tokenId.
  /// @param _tokenId ERC1155 Token id.
  /// @return amount0 The amount of fees collected in token0
  /// @return amount1 The amount of fees collected in token1
  function collectFee(uint256 _tokenId)
    external
    returns (uint256 amount0, uint256 amount1);
}
