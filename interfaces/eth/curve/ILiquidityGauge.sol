// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface ILiquidityGauge {
  function minter() external view returns (address);

  function crv_token() external view returns (address);

  function lp_token() external view returns (address);

  function balanceOf(address addr) external view returns (uint);

  function claimable_tokens(address addr) external view returns (uint);

  function deposit(uint value) external;

  function withdraw(uint value) external;
}
