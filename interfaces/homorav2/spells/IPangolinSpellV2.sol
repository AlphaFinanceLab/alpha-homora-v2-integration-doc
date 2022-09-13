// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IPangolinSpellV2 {
  struct Amounts {
    uint amtAUser; // Supplied tokenA amount
    uint amtBUser; // Supplied tokenB amount
    uint amtLPUser; // Supplied LP token amount
    uint amtABorrow; // Borrow tokenA amount
    uint amtBBorrow; // Borrow tokenB amount
    uint amtLPBorrow; // Borrow LP token amount (should be 0, not support borrowing LP tokens)
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
  }
  struct RepayAmounts {
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP that user receives (remainings are converted to underlying tokens).
    uint amtARepay; // Amount of tokenA that user repays (repay all -> type(uint).max)
    uint amtBRepay; // Amount of tokenB that user repays (repay all -> type(uint).max)
    uint amtLPRepay; // Amount of LP that user repays (should be 0, not support borrowing LP tokens).
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
  }

  /// @dev Add liquidity to Pangolin pool, with staking to miniChef
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to supply, borrow, and get.
  /// @param pid Pool id
  function addLiquidityWMiniChef(
    address tokenA,
    address tokenB,
    Amounts calldata amt,
    uint pid
  ) external payable;

  // @dev Remove liquidity from Pangolin pool, from miniChef staking
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to take out, withdraw, repay, and get.
  function removeLiquidityWMiniChef(
    address tokenA,
    address tokenB,
    RepayAmounts calldata amt
  ) external;

  /// @dev Harvest staking reward tokens to in-exec position's owner
  function harvestWMiniChefRewards() external;
}
