// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../BaseIntegration.sol";
import "../../../utils/HomoraMath.sol";
import "../../../../interfaces/avax/IBankAVAX.sol";
import "../../../../interfaces/avax/pangolin/IMiniChefV2PNG.sol";
import "../../../../interfaces/avax/pangolin/IWMiniChefV2PNG.sol";
import "../../../../interfaces/avax/pangolin/IPangolinSpellV2.sol";
import "../../../../interfaces/avax/pangolin/IPangolinFactory.sol";

import "forge-std/console2.sol";

contract PangolinSpellV2Integration is BaseIntegration {
    using SafeERC20 for IERC20;
    using HomoraMath for uint256;

    IBankAVAX bank; // homora bank
    IPangolinFactory factory; // pangolin factory

    // addLiquidityWMiniChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256),uint256)
    bytes4 addLiquiditySelector = 0x2951434c;

    // removeLiquidityWMiniChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))
    bytes4 removeLiquiditySelector = 0xde1ecfce;

    // harvestWMiniChefRewards()
    bytes4 harvestRewardsSelector = 0x32032b5a;

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
        uint256 pid; // pool id of MinichefV2
    }

    struct RemoveLiquidityParams {
        address tokenA; // The first token of pool
        address tokenB; // The second token of pool
        uint256 amtLPTake; // Amount of LP being removed from the position
        uint256 amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to tokenA, tokenB)
        uint256 amtARepay; // Repay tokenA amount
        uint256 amtBRepay; // Repay tokenB amount
        uint256 amtLPRepay; // Repay LP token amount
        uint256 amtAMin; // Desired tokenA amount
        uint256 amtBMin; // Desired tokenB amount
    }

    constructor(IBankAVAX _bank, IPangolinFactory _factory) {
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
                IPangolinSpellV2.Amounts(
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
        address rewardToken = getRewardToken(_positionId);

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
                IPangolinSpellV2.Amounts(
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
        doRefund(rewardToken);
    }

    function reducePosition(
        address _spell,
        uint256 _positionId,
        RemoveLiquidityParams memory _params
    ) external {
        address lp = factory.getPair(_params.tokenA, _params.tokenB);
        address rewardToken = getRewardToken(_positionId);

        bank.execute(
            _positionId,
            _spell,
            abi.encodeWithSelector(
                removeLiquiditySelector,
                _params.tokenA,
                _params.tokenB,
                IPangolinSpellV2.RepayAmounts(
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
        doRefund(rewardToken);
    }

    function harvestRewards(address _spell, uint256 _positionId) external {
        bank.execute(
            _positionId,
            _spell,
            abi.encodeWithSelector(harvestRewardsSelector)
        );

        // find reward token address from wrapper
        address rewardToken = getRewardToken(_positionId);

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

        IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);
        IMiniChefV2PNG chef = IMiniChefV2PNG(wrapper.chef());

        // get info for calculating rewards
        (uint256 pid, uint256 startRewardTokenPerShare) = wrapper.decodeId(
            collateralId
        );
        (uint256 endRewardTokenPerShare, , ) = chef.poolInfo(pid);
        (uint256 totalSupply, ) = chef.userInfo(pid, address(wrapper)); // total lp from wrapper deposited in Chef

        // calculate pending rewards
        uint256 PRECISION = 1e12;
        uint256 stReward = (startRewardTokenPerShare * totalSupply).divCeil(
            PRECISION
        );
        uint256 enReward = (endRewardTokenPerShare * totalSupply) / PRECISION;

        pendingRewards = (enReward > stReward) ? enReward - stReward : 0;
    }

    function getRewardToken(uint256 _positionId)
        internal
        view
        returns (address rewardToken)
    {
        // query position info from position id
        (, address collateralTokenAddress, , ) = bank.getPositionInfo(
            _positionId
        );

        IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);

        // find reward token address from wrapper
        rewardToken = address(wrapper.png());
    }
}
