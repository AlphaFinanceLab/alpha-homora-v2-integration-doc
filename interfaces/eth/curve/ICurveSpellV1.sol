// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface ICurveSpellV1 {
  function addLiquidity3(
    address lp,
    uint[3] calldata amtsUser, // User's provided amount (order of tokens are aligned with the registry).
    uint amtLPUser, // user's provided LP amount.
    uint[3] calldata amtsBorrow, // borrow amount (order of tokens are aligned with the registry).
    uint amtLPBorrow, // LP borrow amount.
    uint minLPMint, // minimum LP gain (slippage control).
    uint pid, // pool ID (curve).
    uint gid // gauge ID (curve).
  ) external;

  function removeLiquidity3(
    address lp,
    uint amtLPTake, // LP amount being taken out from Homora.
    uint amtLPWithdraw, // LP amount that we transfer to caller (owner).
    uint[3] calldata amtsRepay, // Repay token amounts (order of tokens are aligned with the registry)
    uint amtLPRepay, // Repay LP amounts
    uint[3] calldata amtsMin //minimum gain after removeLiquidity (slippage control; order of tokens are aligned with the registry)
  ) external;

  function harvest() external;
}
