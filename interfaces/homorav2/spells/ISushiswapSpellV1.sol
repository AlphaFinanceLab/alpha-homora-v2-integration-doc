// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface ISushiswapSpellV1 {
  struct Amounts {
    uint amtAUser; // Supplied tokenA amount
    uint amtBUser; // Supplied tokenB amount
    uint amtLPUser; // Supplied LP token amount
    uint amtABorrow; // Borrow tokenA amount
    uint amtBBorrow; // Borrow tokenB amount
    uint amtLPBorrow; // Borrow LP token amount
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
  }
  struct RepayAmounts {
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to tokenA, tokenB)
    uint amtARepay; // Repay tokenA amount (repay all -> type(uint).max)
    uint amtBRepay; // Repay tokenB amount (repay all -> type(uint).max)
    uint amtLPRepay; // Repay LP token amount
    uint amtAMin; // Desired tokenA amount
    uint amtBMin; // Desired tokenB amount
  }

  /// @dev Add liquidity to sushiswap pool, with staking to masterchef
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to supply, borrow, and get.
  function addLiquidityWMasterChef(
    address tokenA,
    address tokenB,
    Amounts calldata amt,
    uint pid
  ) external payable;

  // @dev Remove liquidity from sushiswap pool, from masterchef staking
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to take out, withdraw, repay, and get.
  function removeLiquidityWMasterChef(
    address tokenA,
    address tokenB,
    RepayAmounts calldata amt
  ) external;

  function harvestWMasterChef() external;
}
