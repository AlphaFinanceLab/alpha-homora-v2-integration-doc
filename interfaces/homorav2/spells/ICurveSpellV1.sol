// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface ICurveSpellV1 {
  function addLiquidity3(
    address lp, // LP token for the pool
    uint[3] calldata amtsUser, // Supplied tokens amount (order of tokens are aligned with the registry).
    uint amtLPUser, // Supplied LP token amount.
    uint[3] calldata amtsBorrow, // Borrow amount (order of tokens are aligned with the registry).
    uint amtLPBorrow, // Borrow LP token amount (should be 0, not support borrowing LP tokens)
    uint minLPMint, // minimum LP gain (slippage control).
    uint pid, // pool ID (curve).
    uint gid // gauge ID (curve).
  ) external;

  function removeLiquidity3(
    address lp, // LP token for the pool
    uint amtLPTake, // Amount of LP being removed from the position
    uint amtLPWithdraw, // Amount of LP that user receives (remainings are converted to underlying tokens).
    uint[3] calldata amtsRepay, // Amount of tokens that user repays (repay all -> type(uint).max)
    uint amtLPRepay, // Amount of LP that user repays (should be 0, not support borrowing LP tokens).
    uint[3] calldata amtsMin //minimum gain after removeLiquidity (slippage control; order of tokens are aligned with the registry)
  ) external;

  function harvest() external;
}
