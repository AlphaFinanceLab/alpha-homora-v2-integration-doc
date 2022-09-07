// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../../BaseIntegration.sol';
import '../../utils/HomoraMath.sol';
import '../../../interfaces/ftm/IBankFTM.sol';
import '../../../interfaces/ftm/beets/IBeetsSpellV1.sol';
import '../../../interfaces/ftm/beets/IMasterChefBeets.sol';
import '../../../interfaces/ftm/beets/IWMasterChefBeetsWorker.sol';
import '../../../interfaces/ftm/beets/IBeetsVault.sol';

import 'forge-std/console2.sol';

contract BeetsSpellV1Integration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankFTM bank; // homora bank
  IBeetsVault vault; // beets vault

  // addLiquidityWMasterChef(bytes32,(uint256[],uint256,uint256[],uint256,uint256),uint256)
  bytes4 addLiquiditySelector = 0xa3be0614;

  // removeLiquidityWMasterChef(bytes32,(uint256,uint256,uint256[],uint256,uint256[]))
  bytes4 removeLiquiditySelector = 0x25c556b2;

  // harvestWMasterChef()
  bytes4 harvestRewardsSelector = 0x40a65ad2;

  uint constant PRECISION = 10**12;

  struct AddLiquidityParams {
    bytes32 poolId; // poolId in Vault
    uint[] amtsUser; // Supplied tokens amount
    uint amtLPUser; // Supplied LP token amount
    uint[] amtsBorrow; // Borrow tokens amount
    uint amtLPBorrow; // Borrow LP token amount
    uint minLPMint; // Desired LP token amount (slippage control)
    uint pid; // pool id of BoostedMasterChefReward
  }

  struct RemoveLiquidityParams {
    bytes32 poolId; // poolId in Vault
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to each tokens)
    uint[] amtsRepay; // Repay tokens amount (repay all -> type(uint).max)
    uint amtLPRepay; // Repay LP token amount
    uint[] amtsMin; // Desired tokens amount
  }

  constructor(IBankFTM _bank, IBeetsVault _factory) {
    bank = _bank;
    vault = _factory;
  }

  function openPosition(address _spell, AddLiquidityParams memory _params)
    external
    returns (uint positionId)
  {
    (address[] memory tokens, address lp) = getPoolTokensAndLp(_params.poolId);

    // approve tokens
    for (uint i = 0; i < tokens.length; i++) {
      ensureApprove(tokens[i], address(bank));
    }
    ensureApprove(lp, address(bank));

    // transfer tokens from user
    for (uint i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    IERC20(lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

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
    for (uint i = 0; i < tokens.length; i++) {
      doRefund(tokens[i]);
    }
    doRefund(lp);
  }

  function increasePosition(
    uint _positionId,
    address _spell,
    AddLiquidityParams memory _params
  ) external {
    (address[] memory tokens, address lp) = getPoolTokensAndLp(_params.poolId);
    address rewardToken = getRewardToken(_positionId);

    // approve tokens
    for (uint i = 0; i < tokens.length; i++) {
      ensureApprove(tokens[i], address(bank));
    }
    ensureApprove(lp, address(bank));

    // transfer tokens from user
    for (uint i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    IERC20(lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

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
    for (uint i = 0; i < tokens.length; i++) {
      doRefund(tokens[i]);
    }
    doRefund(lp);
    doRefund(rewardToken);
  }

  function reducePosition(
    address _spell,
    uint _positionId,
    RemoveLiquidityParams memory _params
  ) external {
    (address[] memory tokens, address lp) = getPoolTokensAndLp(_params.poolId);
    address rewardToken = getRewardToken(_positionId);

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
    for (uint i = 0; i < tokens.length; i++) {
      doRefund(tokens[i]);
    }
    doRefund(lp);
    doRefund(rewardToken);
  }

  function harvestRewards(address _spell, uint _positionId) external {
    bank.execute(_positionId, _spell, abi.encodeWithSelector(harvestRewardsSelector));

    address rewardToken = getRewardToken(_positionId);

    doRefund(rewardToken);
  }

  function getPendingRewards(uint _positionId) external view returns (uint pendingRewards) {
    // query position info from position id
    (, address collateralTokenAddress, uint collateralId, uint collateralAmount) = bank
      .getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);
    IMasterChefBeets chef = IMasterChefBeets(wrapper.chef());

    // get info for calculating rewards
    (uint pid, uint startRewardTokenPerShare) = wrapper.decodeId(collateralId);
    uint endRewardTokenPerShare = wrapper.accRewardPerShare();
    (uint totalSupply, ) = chef.userInfo(pid, address(wrapper)); // total lp from wrapper deposited in Chef

    // pending rewards separates into two parts
    // 1. pending rewards that are in the wrapper contract
    // 2. pending rewards that wrapper hasn't claimed from Chef's contract
    uint pendingRewardFromChef = chef.pendingBeets(pid, address(wrapper));
    endRewardTokenPerShare += (pendingRewardFromChef * PRECISION) / totalSupply;

    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;

    pendingRewards = (enReward > stReward) ? enReward - stReward : 0;
  }

  function getPoolTokensAndLp(bytes32 _poolId)
    internal
    view
    returns (address[] memory tokens, address lp)
  {
    (lp, ) = vault.getPool(_poolId);
    (tokens, , ) = vault.getPoolTokens(_poolId);
  }

  function getRewardToken(uint _positionId) internal view returns (address rewardToken) {
    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);

    // find reward token address
    rewardToken = address(wrapper.rewardToken());
  }
}
