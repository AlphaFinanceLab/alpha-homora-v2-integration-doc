// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC1155/IERC1155.sol';
import './IUniswapV3PositionManager.sol';
import '../../IGovernable.sol';

interface IWUniswapV3Position is IERC1155, IGovernable {
  struct PositionInfo {
    uint uniV3PositionManagerId;
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
  function positions(uint _uniV3PositionId) external view returns (PositionInfo memory info);

  /// @dev get uniswap v3 position manager
  function positionManager() external view returns (IUniswapV3PositionManager positionManager);

  /// @dev get underlying pool from token id
  /// @param _tokenId token id
  /// @return pool uniswap v3 pool address
  function getUnderlyingToken(uint _tokenId) external view returns (address pool);

  /// @dev get underlying rate
  function getUnderlyingRate(uint) external returns (uint);

  /// @dev get uniswap v3 position info from token id
  function getPositionInfoFromTokenId(uint _tokenId)
    external
    view
    returns (PositionInfo memory info);

  function mint(uint _uniV3PositionManagerId, address _bene)
    external
    returns (uint id, uint amount);

  function sync(uint _tokenId) external returns (uint id, uint amount);

  function burn(
    uint _tokenId,
    uint _amount,
    uint _minAmt0,
    uint _minAmt1,
    uint _deadline
  ) external returns (uint amount0, uint amount1);

  function collectFee(uint _tokenId) external returns (uint amount0, uint amount1);
}
