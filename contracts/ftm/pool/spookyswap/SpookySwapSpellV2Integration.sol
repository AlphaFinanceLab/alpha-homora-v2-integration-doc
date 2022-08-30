// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../BaseIntegration.sol";
import "../../../../interfaces/ftm/IBankFTM.sol";
import "../../../../interfaces/ftm/spookyswap/ISpookySwapSpellV2.sol";
import "../../../../interfaces/ftm/spookyswap/IMasterChefBooV2.sol";
import "../../../../interfaces/ftm/spookyswap/IWMasterChefBooV2.sol";
import "../../../../interfaces/ftm/spookyswap/ISpookySwapFactory.sol";

import "forge-std/console2.sol";

contract SpookySwapSpellV2Integration is BaseIntegration {
    using SafeERC20 for IERC20;

    IBankFTM bank; // homora bank
    ISpookySwapFactory factory; // spookyswap factory

    // addLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256),uint256)
    bytes4 addLiquiditySelector = 0xe07d904e;

    // removeLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))
    bytes4 removeLiquiditySelector = 0x95723b1c;

    // harvestWMasterChef()
    bytes4 harvestRewardsSelector = 0x40a65ad2;

    struct AddLiquidityParams {
        address tokenA; // The first token of pool
        address tokenB; // The second token of pool
        uint256 amtAUser; // Supplied tokenA amount
        uint256 amtBUser; // Supplied tokenB amount
        uint256 amtLPUser; // Supplied LP token amount
        uint256 amtABorrow; // Borrow tokenA amount
        uint256 amtBBorrow; // Borrow tokenB amount
        uint256 amtLPBorrow; // Borrow LP token amount
        uint256 amtAMin; // Desired tokenA amount (slippage control)
        uint256 amtBMin; // Desired tokenB amount (slippage control)
        uint256 pid; // pool id of BoostedMasterChefReward
    }

    struct RemoveLiquidityParams {
        address tokenA; // The first token of pool
        address tokenB; // The second token of pool
        uint256 amtLPTake; // Amount of LP being removed from the position
        uint256 amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to tokenA, tokenB)
        uint256 amtARepay; // Repay tokenA amount (repay all -> type(uint).max)
        uint256 amtBRepay; // Repay tokenB amount (repay all -> type(uint).max)
        uint256 amtLPRepay; // Repay LP token amount
        uint256 amtAMin; // Desired tokenA amount
        uint256 amtBMin; // Desired tokenB amount
    }

    constructor(IBankFTM _bank, ISpookySwapFactory _factory) {
        bank = _bank;
        factory = _factory;
    }

    function openPosition(address spell, AddLiquidityParams memory params)
        external
        returns (uint256 positionId)
    {
        address lp = factory.getPair(params.tokenA, params.tokenB);

        // approve tokens
        ensureApprove(params.tokenA, address(bank));
        ensureApprove(params.tokenB, address(bank));
        ensureApprove(lp, address(bank));

        // transfer tokens from user
        IERC20(params.tokenA).safeTransferFrom(
            msg.sender,
            address(this),
            params.amtAUser
        );
        IERC20(params.tokenB).safeTransferFrom(
            msg.sender,
            address(this),
            params.amtBUser
        );
        IERC20(lp).safeTransferFrom(
            msg.sender,
            address(this),
            params.amtLPUser
        );

        positionId = bank.execute(
            0, // (0 is reserved for opening new position)
            spell,
            abi.encodeWithSelector(
                addLiquiditySelector,
                params.tokenA,
                params.tokenB,
                ISpookySwapSpellV2.Amounts(
                    params.amtAUser,
                    params.amtBUser,
                    params.amtLPUser,
                    params.amtABorrow,
                    params.amtBBorrow,
                    params.amtLPBorrow,
                    params.amtAMin,
                    params.amtBMin
                ),
                params.pid
            )
        );

        doRefundETH();
        doRefund(params.tokenA);
        doRefund(params.tokenB);
        doRefund(lp);
    }

    function increasePosition(
        uint256 positionId,
        address spell,
        AddLiquidityParams memory params
    ) external {
        address lp = factory.getPair(params.tokenA, params.tokenB);

        // approve tokens
        ensureApprove(params.tokenA, address(bank));
        ensureApprove(params.tokenB, address(bank));
        ensureApprove(lp, address(bank));

        // transfer tokens from user
        IERC20(params.tokenA).safeTransferFrom(
            msg.sender,
            address(this),
            params.amtAUser
        );
        IERC20(params.tokenB).safeTransferFrom(
            msg.sender,
            address(this),
            params.amtBUser
        );
        IERC20(lp).safeTransferFrom(
            msg.sender,
            address(this),
            params.amtLPUser
        );

        bank.execute(
            positionId,
            spell,
            abi.encodeWithSelector(
                addLiquiditySelector,
                params.tokenA,
                params.tokenB,
                ISpookySwapSpellV2.Amounts(
                    params.amtAUser,
                    params.amtBUser,
                    params.amtLPUser,
                    params.amtABorrow,
                    params.amtBBorrow,
                    params.amtLPBorrow,
                    params.amtAMin,
                    params.amtBMin
                ),
                params.pid
            )
        );

        doRefundETH();
        doRefund(params.tokenA);
        doRefund(params.tokenB);
        doRefund(lp);
    }

    function reducePosition(
        address spell,
        uint256 positionId,
        RemoveLiquidityParams memory params
    ) external {
        address lp = factory.getPair(params.tokenA, params.tokenB);

        bank.execute(
            positionId,
            spell,
            abi.encodeWithSelector(
                removeLiquiditySelector,
                params.tokenA,
                params.tokenB,
                ISpookySwapSpellV2.RepayAmounts(
                    params.amtLPTake,
                    params.amtLPWithdraw,
                    params.amtARepay,
                    params.amtBRepay,
                    params.amtLPRepay,
                    params.amtAMin,
                    params.amtBMin
                )
            )
        );

        doRefundETH();
        doRefund(params.tokenA);
        doRefund(params.tokenB);
        doRefund(lp);
    }

    function harvestRewards(address spell, uint256 positionId) external {
        bank.execute(
            positionId,
            spell,
            abi.encodeWithSelector(harvestRewardsSelector)
        );

        // query position info from position id
        (, address collateralTokenAddress, , ) = bank.getPositionInfo(
            positionId
        );

        IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);

        // find reward token address from wrapper
        address rewardToken = address(wrapper.rewardToken());

        doRefund(rewardToken);
    }

    function getPendingRewards(uint256 positionId)
        external
        view
        returns (uint256 pendingRewards)
    {
        // query position info from position id
        (
            ,
            address collateralTokenAddress,
            uint256 collateralId,
            uint256 collateralAmount
        ) = bank.getPositionInfo(positionId);

        IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);
        IMasterChefBooV2 chef = IMasterChefBooV2(wrapper.chef());

        // get info for calculating rewards
        (uint256 pid, uint256 startTokenPerShare) = wrapper.decodeId(
            collateralId
        );
        uint256 endTokenPerShare = wrapper.accRewardPerShare();
        (uint256 amount, ) = chef.userInfo(pid, address(wrapper));

        // pending rewards that wrapper hasn't claimed
        uint256 pendingReward = chef.pendingBOO(pid, address(wrapper));

        // calculate pending rewards
        uint256 pendingRewardPerShareFromChef = (pendingReward * 10**18) /
            amount;

        uint256 increasingRewardPerShare = endTokenPerShare -
            startTokenPerShare +
            pendingRewardPerShareFromChef;

        pendingRewards = (collateralAmount * increasingRewardPerShare) / 10**18;
    }
}
