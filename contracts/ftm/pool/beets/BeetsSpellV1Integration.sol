// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../BaseIntegration.sol";
import "../../../utils/HomoraMath.sol";
import "../../../../interfaces/ftm/IBankFTM.sol";
import "../../../../interfaces/ftm/beets/IBeetsSpellV1.sol";
import "../../../../interfaces/ftm/beets/IMasterChefBeets.sol";
import "../../../../interfaces/ftm/beets/IWMasterChefBeetsWorker.sol";
import "../../../../interfaces/ftm/beets/IBeetsVault.sol";

import "forge-std/console2.sol";

contract BeetsSpellV1Integration is BaseIntegration {
    using SafeERC20 for IERC20;
    using HomoraMath for uint256;

    IBankFTM bank; // homora bank
    IBeetsVault vault; // beets vault

    // addLiquidityWMasterChef(bytes32,(uint256[],uint256,uint256[],uint256,uint256),uint256)
    bytes4 addLiquiditySelector = 0xa3be0614;

    // removeLiquidityWMasterChef(bytes32,(uint256,uint256,uint256[],uint256,uint256[]))
    bytes4 removeLiquiditySelector = 0x25c556b2;

    // harvestWMasterChef()
    bytes4 harvestRewardsSelector = 0x40a65ad2;

    struct AddLiquidityParams {
        bytes32 poolId; // poolId in Vault
        uint256[] amtsUser; // Supplied tokens amount
        uint256 amtLPUser; // Supplied LP token amount
        uint256[] amtsBorrow; // Borrow tokens amount
        uint256 amtLPBorrow; // Borrow LP token amount
        uint256 minLPMint; // Desired LP token amount (slippage control)
        uint256 pid; // pool id of BoostedMasterChefReward
    }

    struct RemoveLiquidityParams {
        bytes32 poolId; // poolId in Vault
        uint256 amtLPTake; // Amount of LP being removed from the position
        uint256 amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to each tokens)
        uint256[] amtsRepay; // Repay tokens amount (repay all -> type(uint).max)
        uint256 amtLPRepay; // Repay LP token amount
        uint256[] amtsMin; // Desired tokens amount
    }

    constructor(IBankFTM _bank, IBeetsVault _factory) {
        bank = _bank;
        vault = _factory;
    }

    function openPosition(address _spell, AddLiquidityParams memory _params)
        external
        returns (uint256 positionId)
    {
        (address[] memory tokens, address lp) = getPoolTokensAndLp(
            _params.poolId
        );

        // approve tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            ensureApprove(tokens[i], address(bank));
        }
        ensureApprove(lp, address(bank));

        // transfer tokens from user
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(
                msg.sender,
                address(this),
                _params.amtsUser[i]
            );
        }
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
                _params.poolId,
                IBeetsSpellV1.Amounts(
                    _params.amtsUser,
                    _params.amtLPUser,
                    _params.amtsBorrow,
                    _params.amtLPBorrow,
                    _params.minLPMint
                ),
                _params.pid
            )
        );

        doRefundETH();
        for (uint256 i = 0; i < tokens.length; i++) {
            doRefund(tokens[i]);
        }
        doRefund(lp);
    }

    function increasePosition(
        uint256 _positionId,
        address _spell,
        AddLiquidityParams memory _params
    ) external {
        (address[] memory tokens, address lp) = getPoolTokensAndLp(
            _params.poolId
        );

        // approve tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            ensureApprove(tokens[i], address(bank));
        }
        ensureApprove(lp, address(bank));

        // transfer tokens from user
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(
                msg.sender,
                address(this),
                _params.amtsUser[i]
            );
        }
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
                _params.poolId,
                IBeetsSpellV1.Amounts(
                    _params.amtsUser,
                    _params.amtLPUser,
                    _params.amtsBorrow,
                    _params.amtLPBorrow,
                    _params.minLPMint
                ),
                _params.pid
            )
        );

        doRefundETH();
        for (uint256 i = 0; i < tokens.length; i++) {
            doRefund(tokens[i]);
        }
        doRefund(lp);
    }

    function reducePosition(
        address _spell,
        uint256 _positionId,
        RemoveLiquidityParams memory _params
    ) external {
        (address[] memory tokens, address lp) = getPoolTokensAndLp(
            _params.poolId
        );

        bank.execute(
            _positionId,
            _spell,
            abi.encodeWithSelector(
                removeLiquiditySelector,
                _params.poolId,
                IBeetsSpellV1.RepayAmounts(
                    _params.amtLPTake,
                    _params.amtLPWithdraw,
                    _params.amtsRepay,
                    _params.amtLPRepay,
                    _params.amtsMin
                )
            )
        );

        doRefundETH();
        for (uint256 i = 0; i < tokens.length; i++) {
            doRefund(tokens[i]);
        }
        doRefund(lp);

        // todo: return reward token
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

        IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(
            collateralTokenAddress
        );

        // find reward token address from wrapper
        address rewardToken = address(wrapper.rewardToken());

        doRefund(rewardToken);
    }

    // function getPendingRewards(uint256 _positionId)
    //     external
    //     view
    //     returns (uint256 pendingRewards)
    // {
    //     // query position info from position id
    //     (
    //         ,
    //         address collateralTokenAddress,
    //         uint256 collateralId,
    //         uint256 collateralAmount
    //     ) = bank.getPositionInfo(_positionId);

    //     IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(
    //         collateralTokenAddress
    //     );
    //     IMasterChefBeets chef = IMasterChefBeets(wrapper.chef());

    //     // get info for calculating rewards
    //     (uint256 pid, uint256 startTokenPerShare) = wrapper.decodeId(
    //         collateralId
    //     );
    //     uint256 endTokenPerShare = wrapper.accRewardPerShare();
    //     (uint256 totalSupply, ) = chef.userInfo(pid, address(wrapper)); // total lp from wrapper deposited in Chef

    //     // pending rewards separates into two parts
    //     // 1. pending rewards that are in the wrapper contract
    //     uint256 PRECISION = 10**12;
    //     uint256 stReward = (startTokenPerShare * collateralAmount).divCeil(
    //         PRECISION
    //     );
    //     uint256 enReward = (endTokenPerShare * collateralAmount) / PRECISION;
    //     uint256 userPendingRewardsFromWrapper = (enReward > stReward)
    //         ? enReward - stReward
    //         : 0;

    //     // 2. pending rewards that wrapper hasn't claimed from Chef's contract
    //     uint256 pendingRewardFromChef = chef.pendingBOO(pid, address(wrapper));
    //     uint256 userPendingRewardFromChef = (collateralAmount *
    //         pendingRewardFromChef) / totalSupply;

    //     pendingRewards =
    //         userPendingRewardsFromWrapper +
    //         userPendingRewardFromChef;
    // }

    function getPoolTokensAndLp(bytes32 _poolId)
        internal
        returns (address[] memory tokens, address lp)
    {
        (lp, ) = vault.getPool(_poolId);
        (tokens, , ) = vault.getPoolTokens(_poolId);
    }
}
