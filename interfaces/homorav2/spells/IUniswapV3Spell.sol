// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IUniswapV3Spell {
  struct OpenPositionParams {
    address token0; // token0 of the pool.
    address token1; // token1 of the pool.
    uint24 fee; // pool fee.
    int24 tickLower; // tickLower
    int24 tickUpper; // tickUpper
    uint amt0User; // token0 amount that user provides.
    uint amt1User; // token1 amount that user provides.
    uint amt0Borrow; // token0 amount that user borrows.
    uint amt1Borrow; // token1 amount that user borrows.
    uint amt0Min; // minimum amount of token0 being used to provide liquidity.
    uint amt1Min; // minimum amount of token1 being used to provide liquidity.
    uint amtInOptimalSwap; // amount of tokens being used in swap for optimal deposit.
    uint amtOutMinOptimalSwap; // expected amount out for optimal deposit.
    bool isZeroForOneSwap; // do we swap token0 to token1 for optimal deposit.
    uint deadline; // deadline for increaseLiquidity and swap.
  }

  struct AddLiquidityParams {
    uint amt0User; // token0 amount that user provides.
    uint amt1User; // token1 amount that user provides.
    uint amt0Borrow; // token0 amount that user borrows.
    uint amt1Borrow; // token1 amount that user borrows.
    uint amt0Min; // minimum amount of token0 being used to provide liquidity.
    uint amt1Min; // minimum amount of token1 being used to provide liquidity.
    uint amtInOptimalSwap; // amount of tokens being used in swap for optimal deposit.
    uint amtOutMinOptimalSwap; // expected amount out for optimal deposit.
    bool isZeroForOneSwap; // do we swap token0 to token1 for optimal deposit.
    uint deadline; // deadline for increaseLiquidity and swap.
  }

  struct RemoveLiquidityParams {
    uint amtLiquidityTake; // amount of liquidity being removed.
    uint amt0Repay; // repay amount of token0.
    uint amt1Repay; // repay amount of token1.
    uint amt0Min; // minimum amount of token0 gain after remove liquidity and repay debt.
    uint amt1Min; // minimum amount of token1 gain after remove liquidity and repay debt.
    uint deadline; // deadline for decreaseLiquidity.
  }

  struct ClosePositionParams {
    uint amt0Min; // minimum amount of token0 gain after remove liquidity and repay debt.
    uint amt1Min; // minimum amount of token1 gain after remove liquidity and repay debt.
    uint deadline; // deadline for decreaseLiquidity.
    bool convertWETH; // convert weth to eth or not (true -> convert to eth)
  }

  struct ReinvestParams {
    uint amtInOptimalSwap; // amount of tokens being used in swap for optimal deposit.
    uint amtOutMinOptimalSwap; // expected amount out for optimal deposit.
    bool isZeroForOneSwap; // do we swap token0 to token1 for optimal deposit.
    uint amt0Min; // minimum amount of token0 being used to provide liquidity.
    uint amt1Min; // minimum amount of token1 being used to provide liquidity.
    uint deadline; // deadline for increaseLiquidity.
  }

  /// @dev open new position.
  /// @param _params open position parameters.
  function openPosition(OpenPositionParams calldata _params) external payable;

  /// @dev add liquidity into the same position.
  /// @param _params addliquidity parameters.
  function addLiquidity(AddLiquidityParams calldata _params) external payable;

  /// @dev remove liquidity from the position.
  /// @param _params removeLiquidity parameters.
  function removeLiquidity(RemoveLiquidityParams calldata _params) external;

  /// @dev collect fee from the position.
  /// @param _convertWETH whether we convert WETH from user wallet to ETH.
  function harvest(bool _convertWETH) external;

  /// @dev close the position (collect Fee, remove all liquidity, and repay).
  /// @param _params closePosition parameters.
  function closePosition(ClosePositionParams calldata _params) external;

  /// @dev collect fee and increase liquidity into the position.
  /// @param _params reinvest parameters.
  function reinvest(ReinvestParams calldata _params) external;
}
