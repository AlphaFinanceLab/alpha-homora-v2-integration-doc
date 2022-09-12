// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IUniswapV2SpellV1 {
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
