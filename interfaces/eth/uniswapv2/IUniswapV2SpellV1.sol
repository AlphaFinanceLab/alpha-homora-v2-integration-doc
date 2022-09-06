// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IUniswapV2SpellV1 {
  struct Amounts {
    uint256 amtAUser; // Supplied tokenA amount
    uint256 amtBUser; // Supplied tokenB amount
    uint256 amtLPUser; // Supplied LP token amount
    uint256 amtABorrow; // Borrow tokenA amount
    uint256 amtBBorrow; // Borrow tokenB amount
    uint256 amtLPBorrow; // Borrow LP token amount
    uint256 amtAMin; // Desired tokenA amount (slippage control)
    uint256 amtBMin; // Desired tokenB amount (slippage control)
  }
  struct RepayAmounts {
    uint256 amtLPTake; // Amount of LP being removed from the position
    uint256 amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to tokenA, tokenB)
    uint256 amtARepay; // Repay tokenA amount (repay all -> type(uint).max)
    uint256 amtBRepay; // Repay tokenB amount (repay all -> type(uint).max)
    uint256 amtLPRepay; // Repay LP token amount
    uint256 amtAMin; // Desired tokenA amount
    uint256 amtBMin; // Desired tokenB amount
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

  // @dev Remove liquidity from UniswapV2 pool, from miniChef staking
  /// @param tokenA Token A for the pair
  /// @param tokenB Token B for the pair
  /// @param amt Amounts of tokens to take out, withdraw, repay, and get.
  function removeLiquidityWERC20(
    address tokenA,
    address tokenB,
    RepayAmounts calldata amt
  ) external;
}
