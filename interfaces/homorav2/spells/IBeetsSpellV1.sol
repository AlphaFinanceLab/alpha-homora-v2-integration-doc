// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IBeetsSpellV1 {
  struct Amounts {
    uint[] amtsUser; // Supplied tokens amount
    uint amtLPUser; // Supplied LP token amount
    uint[] amtsBorrow; // Borrow tokens amount
    uint amtLPBorrow; // Borrow LP token amount
    uint minLPMint; // Desired LP token amount (slippage control)
  }

  struct RepayAmounts {
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP that user receives (remainings are converted to underlying tokens).
    uint[] amtsRepay; // Amount of tokens that user repays (repay all -> type(uint).max)
    uint amtLPRepay; // Amount of LP that user repays (should be 0, not support borrowing LP tokens).
    uint[] amtsMin; // Desired tokens amount (slippage control)
  }

  /// @dev Add liquidity to vault, with staking to Masterchef.
  /// @param poolId Pool id in vault.
  /// @param amt Amounts of tokens to supply, borrow, and get.
  /// @param pid Pool id in masterchef.
  function addLiquidityWMasterChef(
    bytes32 poolId,
    Amounts calldata amt,
    uint pid
  ) external payable;

  /// @dev Remove liquidity from vault, from MasterChef staking
  /// @param poolId Pool id in vault.
  /// @param amt Amounts of tokens to supply, borrow, and get.
  function removeLiquidityWMasterChef(bytes32 poolId, RepayAmounts calldata amt) external;

  /// @dev Harvest reward tokens to in-exec position's owner
  function harvestWMasterChef() external;
}
