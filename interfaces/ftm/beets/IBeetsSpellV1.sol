// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IBeetsSpellV1 {
    struct Amounts {
        uint256[] amtsUser; // Supplied tokens amount
        uint256 amtLPUser; // Supplied LP token amount
        uint256[] amtsBorrow; // Borrow tokens amount
        uint256 amtLPBorrow; // Borrow LP token amount
        uint256 minLPMint; // Desired LP token amount (slippage control)
    }

    struct RepayAmounts {
        uint256 amtLPTake; // Amount of LP being removed from the position
        uint256 amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to each tokens)
        uint256[] amtsRepay; // Repay tokens amount (repay all -> type(uint).max)
        uint256 amtLPRepay; // Repay LP token amount
        uint256[] amtsMin; // Desired tokens amount
    }

    /// @dev Add liquidity to vault, with staking to Masterchef.
    /// @param poolId Pool id in vault.
    /// @param amt Amounts of tokens to supply, borrow, and get.
    /// @param pid Pool id in masterchef.
    function addLiquidityWMasterChef(
        bytes32 poolId,
        Amounts calldata amt,
        uint256 pid
    ) external payable;

    /// @dev Remove liquidity from vault, from MasterChef staking
    /// @param poolId Pool id in vault.
    /// @param amt Amounts of tokens to supply, borrow, and get.
    function removeLiquidityWMasterChef(
        bytes32 poolId,
        RepayAmounts calldata amt
    ) external;

    /// @dev Harvest reward tokens to in-exec position's owner
    function harvestWMasterChef() external;
}
