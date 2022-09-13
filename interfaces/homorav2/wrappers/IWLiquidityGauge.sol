// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC1155/IERC1155.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';

import '../../curve/ICurveRegistry.sol';
import '../../curve/ILiquidityGauge.sol';
import '../IERC20Wrapper.sol';

interface IWLiquidityGauge is IERC1155, IERC20Wrapper {
  /// @dev Mint ERC1155 token for the given ERC20 token.
  function mint(
    uint pid,
    uint gid,
    uint amount
  ) external returns (uint id);

  /// @dev Burn ERC1155 token to redeem ERC20 token back.
  function burn(uint id, uint amount) external returns (uint pid);

  function crv() external returns (IERC20);

  function registry() external returns (ICurveRegistry);

  function encodeId(
    uint,
    uint,
    uint
  ) external pure returns (uint);

  function decodeId(uint id)
    external
    pure
    returns (
      uint,
      uint,
      uint
    );

  function getUnderlyingTokenFromIds(uint pid, uint gid) external view returns (address);

  function gauges(uint pid, uint gid) external view returns (address, uint);
}
