// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface ITraderJoeSpellV3 {
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
        uint256 amtLPTake; // Take out LP token amount (from Homora)
        uint256 amtLPWithdraw; // Withdraw LP token amount (back to caller)
        uint256 amtARepay; // Repay tokenA amount
        uint256 amtBRepay; // Repay tokenB amount
        uint256 amtLPRepay; // Repay LP token amount
        uint256 amtAMin; // Desired tokenA amount
        uint256 amtBMin; // Desired tokenB amount
    }

    /// @dev Add liquidity to TraderJoe pool, with staking to masterChef
    /// @dev not support pool that has a rewarder.
    /// @param tokenA Token A for the pair
    /// @param tokenB Token B for the pair
    /// @param amt Amounts of tokens to supply, borrow, and get.
    /// @param pid Pool id
    function addLiquidityWMasterChef(
        address tokenA,
        address tokenB,
        Amounts calldata amt,
        uint256 pid
    ) external payable;

    /// @dev Remove liquidity from TraderJoe pool, from masterChef staking
    /// @param tokenA Token A for the pair
    /// @param tokenB Token B for the pair
    /// @param amt Amounts of tokens to take out, withdraw, repay, and get.
    function removeLiquidityWMasterChef(
        address tokenA,
        address tokenB,
        RepayAmounts calldata amt
    ) external;

    /// @dev Harvest Joe reward tokens to in-exec position's owner
    function harvestWMasterChef() external;
}
