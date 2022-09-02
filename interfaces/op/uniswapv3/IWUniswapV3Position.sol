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

  function positions(uint256 _uniV3PositionId)
    external
    view
    returns (PositionInfo memory info);

  function positionManager()
    external
    view
    returns (IUniswapV3PositionManager positionManager);

  function getUnderlyingToken(uint256 _id) external view returns (address pool);

  function getUnderlyingRate(uint256) external returns (uint256);

  function getPositionInfoFromTokenId(uint256 _id)
    external
    view
    returns (PositionInfo memory info);

  function mint(uint256 _uniV3PositionManagerId, address _bene)
    external
    returns (uint256 id, uint256 amount);

  function sync(uint256 _tokenId) external returns (uint256 id, uint256 amount);

  function burn(
    uint256 _tokenId,
    uint256 _amount,
    uint256 _minAmt0,
    uint256 _minAmt1,
    uint256 _deadline
  ) external returns (uint256 amount0, uint256 amount1);

  function collectFee(uint256 _id)
    external
    returns (uint256 amount0, uint256 amount1);
}
