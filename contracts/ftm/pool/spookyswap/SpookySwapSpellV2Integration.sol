// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../BaseIntegration.sol";
import "../../../utils/HomoraMath.sol";
import "../../../../interfaces/ftm/IBankFTM.sol";
import "../../../../interfaces/ftm/spookyswap/ISpookySwapSpellV2.sol";
import "../../../../interfaces/ftm/spookyswap/IMasterChefBooV2.sol";
import "../../../../interfaces/ftm/spookyswap/IWMasterChefBooV2.sol";
import "../../../../interfaces/ftm/spookyswap/ISpookySwapFactory.sol";

import "forge-std/console2.sol";

contract SpookySwapSpellV2Integration is BaseIntegration {
    using SafeERC20 for IERC20;
    using HomoraMath for uint256;

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

    function openPosition(address _spell, AddLiquidityParams memory _params)
        external
        returns (uint256 positionId)
    {
        address lp = factory.getPair(_params.tokenA, _params.tokenB);

        // approve tokens
        ensureApprove(_params.tokenA, address(bank));
        ensureApprove(_params.tokenB, address(bank));
        ensureApprove(lp, address(bank));

        // transfer tokens from user
        IERC20(_params.tokenA).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amtAUser
        );
        IERC20(_params.tokenB).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amtBUser
        );
        IERC20(lp).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amtLPUser
        );

        positionId = bank.execute(
            0, // (0 is reserved for opening new position)
            _spell,
            abi.encodeWithSelector(
                addLiquiditySelector,
                _params.tokenA,
                _params.tokenB,
                ISpookySwapSpellV2.Amounts(
                    _params.amtAUser,
                    _params.amtBUser,
                    _params.amtLPUser,
                    _params.amtABorrow,
                    _params.amtBBorrow,
                    _params.amtLPBorrow,
                    _params.amtAMin,
                    _params.amtBMin
                ),
                _params.pid
            )
        );

        doRefundETH();
        doRefund(_params.tokenA);
        doRefund(_params.tokenB);
        doRefund(lp);
    }

    function increasePosition(
        uint256 _positionId,
        address _spell,
        AddLiquidityParams memory _params
    ) external {
        address lp = factory.getPair(_params.tokenA, _params.tokenB);

        // approve tokens
        ensureApprove(_params.tokenA, address(bank));
        ensureApprove(_params.tokenB, address(bank));
        ensureApprove(lp, address(bank));

        // transfer tokens from user
        IERC20(_params.tokenA).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amtAUser
        );
        IERC20(_params.tokenB).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amtBUser
        );
        IERC20(lp).safeTransferFrom(
            msg.sender,
            address(this),
            _params.amtLPUser
        );

        bank.execute(
            _positionId,
            _spell,
            abi.encodeWithSelector(
                addLiquiditySelector,
                _params.tokenA,
                _params.tokenB,
                ISpookySwapSpellV2.Amounts(
                    _params.amtAUser,
                    _params.amtBUser,
                    _params.amtLPUser,
                    _params.amtABorrow,
                    _params.amtBBorrow,
                    _params.amtLPBorrow,
                    _params.amtAMin,
                    _params.amtBMin
                ),
                _params.pid
            )
        );

        doRefundETH();
        doRefund(_params.tokenA);
        doRefund(_params.tokenB);
        doRefund(lp);
    }

    function reducePosition(
        address _spell,
        uint256 _positionId,
        RemoveLiquidityParams memory _params
    ) external {
        address lp = factory.getPair(_params.tokenA, _params.tokenB);

        bank.execute(
            _positionId,
            _spell,
            abi.encodeWithSelector(
                removeLiquiditySelector,
                _params.tokenA,
                _params.tokenB,
                ISpookySwapSpellV2.RepayAmounts(
                    _params.amtLPTake,
                    _params.amtLPWithdraw,
                    _params.amtARepay,
                    _params.amtBRepay,
                    _params.amtLPRepay,
                    _params.amtAMin,
                    _params.amtBMin
                )
            )
        );

        doRefundETH();
        doRefund(_params.tokenA);
        doRefund(_params.tokenB);
        doRefund(lp);
    }

    function harvestRewards(address _spell, uint256 _positionId) external {
        bank.execute(
            _positionId,
            _spell,
            abi.encodeWithSelector(harvestRewardsSelector)
        );

        // query position info from position id
        (, address collateralTokenAddress, , ) = bank.getPositionInfo(
            _positionId
        );

        IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);

        // find reward token address from wrapper
        address rewardToken = address(wrapper.rewardToken());

        doRefund(rewardToken);
    }

    function getPendingRewards(uint256 _positionId)
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
        ) = bank.getPositionInfo(_positionId);

        IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);
        IMasterChefBooV2 chef = IMasterChefBooV2(wrapper.chef());

        // get info for calculating rewards
        (uint256 pid, uint256 startTokenPerShare) = wrapper.decodeId(
            collateralId
        );
        uint256 endTokenPerShare = wrapper.accRewardPerShare();
        (uint256 totalSupply, ) = chef.userInfo(pid, address(wrapper)); // total lp from wrapper deposited in Chef

        // pending rewards separates into two parts
        // 1. pending rewards that are in the wrapper contract
        uint256 PRECISION = 10**12;
        uint256 stReward = (startTokenPerShare * collateralAmount).divCeil(
            PRECISION
        );
        uint256 enReward = (endTokenPerShare * collateralAmount) / PRECISION;
        uint256 userPendingRewardsFromWrapper = (enReward > stReward)
            ? enReward - stReward
            : 0;

        // 2. pending rewards that wrapper hasn't claimed from Chef's contract
        uint256 pendingRewardFromChef = chef.pendingBOO(pid, address(wrapper));
        uint256 userPendingRewardFromChef = (collateralAmount *
            pendingRewardFromChef) / totalSupply;

        pendingRewards =
            userPendingRewardsFromWrapper +
            userPendingRewardFromChef;
    }
}
