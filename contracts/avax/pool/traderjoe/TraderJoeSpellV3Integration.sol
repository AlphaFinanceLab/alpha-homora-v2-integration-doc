// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../SetupBankAvax.sol";
import "../../../../interfaces/avax/IBankAVAX.sol";
import "../../../../interfaces/avax/ITraderJoeSpellV3.sol";
import "../../../../interfaces/avax/IBoostedMasterChefJoe.sol";
import "../../../../interfaces/avax/IWBoostedMasterChefJoeWorker.sol";

import "forge-std/console2.sol";

contract TraderJoeSpellV3Integration is SetupBankAvax {
    using SafeERC20 for IERC20;

    // addLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256),uint256)
    bytes4 addLiquiditySelector = 0xe07d904e;

    // removeLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))
    bytes4 removeLiquiditySelector = 0x95723b1c;

    // harvestWMasterChef()
    bytes4 harvestRewardsSelector = 0x40a65ad2;

    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint256 amtAUser; // Supplied tokenA amount
        uint256 amtBUser; // Supplied tokenB amount
        uint256 amtLPUser; // Supplied LP token amount
        uint256 amtABorrow; // Borrow tokenA amount
        uint256 amtBBorrow; // Borrow tokenB amount
        uint256 amtLPBorrow; // Borrow LP token amount
        uint256 amtAMin; // Desired tokenA amount (slippage control)
        uint256 amtBMin; // Desired tokenB amount (slippage control)
        uint256 pid;
    }

    struct RemoveLiquidityParams {
        address tokenA;
        address tokenB;
        uint256 amtLPTake; // Amount of LP being removed from the position
        uint256 amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to tokenA, tokenB)
        uint256 amtARepay; // Repay tokenA amount
        uint256 amtBRepay; // Repay tokenB amount
        uint256 amtLPRepay; // Repay LP token amount
        uint256 amtAMin; // Desired tokenA amount
        uint256 amtBMin; // Desired tokenB amount
    }

    function openPosition(address spell, AddLiquidityParams memory params)
        internal
        returns (uint256 positionId)
    {
        positionId = bank.execute(
            0, // (0 is reserved for opening new position)
            spell,
            abi.encodeWithSelector(
                addLiquiditySelector,
                params.tokenA,
                params.tokenB,
                ITraderJoeSpellV3.Amounts(
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
    }

    function increasePosition(
        uint256 positionId,
        address spell,
        AddLiquidityParams memory params
    ) public {
        bank.execute(
            positionId,
            spell,
            abi.encodeWithSelector(
                addLiquiditySelector,
                params.tokenA,
                params.tokenB,
                ITraderJoeSpellV3.Amounts(
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
    }

    function reducePosition(
        address spell,
        uint256 positionId,
        RemoveLiquidityParams memory params
    ) public {
        bank.execute(
            positionId,
            spell,
            abi.encodeWithSelector(
                removeLiquiditySelector,
                params.tokenA,
                params.tokenB,
                ITraderJoeSpellV3.RepayAmounts(
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
    }

    function harvestRewards(address spell, uint256 positionId) public {
        bank.execute(
            positionId,
            spell,
            abi.encodeWithSelector(harvestRewardsSelector)
        );
    }

    function getPendingRewards(uint256 positionId)
        public
        view
        returns (uint256 pendingRewards)
    {
        (
            ,
            address collateralTokenAddress,
            uint256 collateralId,
            uint256 collateralAmount
        ) = bank.getPositionInfo(positionId);

        IWBoostedMasterChefJoeWorker wrapper = IWBoostedMasterChefJoeWorker(
            collateralTokenAddress
        );
        IBoostedMasterChefJoe chef = IBoostedMasterChefJoe(wrapper.chef());

        // get info
        (uint256 pid, uint256 startTokenPerShare) = wrapper.decodeId(
            collateralId
        );
        uint256 endTokenPerShare = wrapper.accJoePerShare();
        IBoostedMasterChefJoe.UserInfo memory userInfo = chef.userInfo(
            pid,
            address(wrapper)
        );

        // pending rewards that wrapper hasn't claimed
        (uint256 pendingJoe, , , ) = chef.pendingTokens(pid, address(wrapper));

        // calculate pending rewards
        uint256 pendingJoePerShareFromChef = (pendingJoe * 10**18) /
            userInfo.amount;

        uint256 increasingJoePerShare = endTokenPerShare -
            startTokenPerShare +
            pendingJoePerShareFromChef;

        pendingRewards = (collateralAmount * increasingJoePerShare) / 10**18;
    }
}
