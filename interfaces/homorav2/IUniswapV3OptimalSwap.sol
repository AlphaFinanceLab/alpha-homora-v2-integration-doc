// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol';

import '../uniswapv3/IUniswapV3Pool.sol';

interface IUniswapV3OptimalSwap {
  /// @dev get amtSwap for optimal deposit (only in tick range)
  /// @param _pool uniswap v3 pool
  /// @param _amt0In desired token0's amount
  /// @param _amt1In desired token1's amount
  /// @param _tickLower desired tick lower (to provide lp)
  /// @param _tickUpper desired tick uppper (to provide lp)
  function getOptimalSwapAmt(
    IUniswapV3Pool _pool,
    uint _amt0In,
    uint _amt1In,
    int24 _tickLower,
    int24 _tickUpper
  )
    external
    view
    returns (
      uint amtSwap,
      uint amtOut,
      bool isZeroForOne
    );

  /// @dev get nearest initialized lower tick and upper tick
  /// @param _pool uniswap v3 pool
  /// @param _tick target tick
  /// @param _amount amount of nearest tick
  /// @return nearestInitializedLeftTicks nearest left ticks that are initialized.
  /// @return isInitializedLeftTicks whether the nearest ticks are initialized (it will be false in case we
  /// cannot find the nearest initialized ticks). the order is aligned with nearestInitializedTicks.
  /// @return nearestInitializedRightTicks nearest right ticks that are initialized.
  /// @return isInitializedRightTicks whether the nearest ticks are initialized (it will be false in case we
  /// cannot find the nearest initialized ticks). the order is aligned with nearestInitializedTicks.
  function nearestInitializedTick(
    IUniswapV3Pool _pool,
    int24 _tick,
    uint24 _amount
  )
    external
    view
    returns (
      int24[] memory nearestInitializedLeftTicks,
      bool[] memory isInitializedLeftTicks,
      int24[] memory nearestInitializedRightTicks,
      bool[] memory isInitializedRightTicks
    );
}
