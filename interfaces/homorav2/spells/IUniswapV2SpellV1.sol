// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IUniswapV2SpellV1 {
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

  /// @dev Add liquidity to UniswapV2 pool, with staking to miniChef
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to supply, borrow, and get.
  function addLiquidityWERC20(
    address tokenA,
    address tokenB,
    Amounts calldata amt
  ) external payable;

  /// @dev Add liquidity to Uniswap pool, with staking rewards
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to supply, borrow, and get.
  /// @param wstaking Wrapped staking rewards address
  function addLiquidityWStakingRewards(
    address tokenA,
    address tokenB,
    Amounts calldata amt,
    address wstaking
  ) external;

  // @dev Remove liquidity from UniswapV2 pool, from miniChef staking
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to take out, withdraw, repay, and get.
  function removeLiquidityWERC20(
    address tokenA,
    address tokenB,
    RepayAmounts calldata amt
  ) external;

  /// @dev Remove liquidity from Uniswap pool, from staking rewards
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to take out, withdraw, repay, and get.
  function removeLiquidityWStakingRewards(
    address tokenA,
    address tokenB,
    RepayAmounts calldata amt,
    address wstaking
  ) external;

  /// @dev Harvest staking reward tokens to in-exec position's owner
  /// @param wstaking Wrapped staking rewards address
  function harvestWStakingRewards(address wstaking) external;
}
