// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../../BaseIntegration.sol';
import '../../utils/HomoraMath.sol';
import '../../../interfaces/avax/IBankAVAX.sol';
import '../../../interfaces/avax/pangolin/IMiniChefV2PNG.sol';
import '../../../interfaces/avax/pangolin/IWMiniChefV2PNG.sol';
import '../../../interfaces/avax/pangolin/IPangolinSpellV2.sol';
import '../../../interfaces/avax/pangolin/IPangolinFactory.sol';

import 'forge-std/console2.sol';

contract PangolinSpellV2Integration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankAVAX bank; // homora bank
  IPangolinFactory factory; // pangolin factory

  uint constant PRECISION = 10**12;

  struct AddLiquidityParams {
    address tokenA; // The first token of pool
    address tokenB; // The second token of pool
    uint amtAUser; // Supplied tokenA amount
    uint amtBUser; // Supplied tokenB amount
    uint amtLPUser; // Supplied LP token amount
    uint amtABorrow; // Borrow tokenA amount
    uint amtBBorrow; // Borrow tokenB amount
    uint amtLPBorrow; // Borrow LP token amount (should be 0, now we support only borrowing based tokens)
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
    uint poolId; // pool id of MinichefV2
  }

  struct RemoveLiquidityParams {
    address tokenA; // The first token of pool
    address tokenB; // The second token of pool
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP that user receives (remainings will be converted to based tokens).
    uint amtARepay; // Amount of tokenA that user repays (repay all -> type(uint).max)
    uint amtBRepay; // Amount of tokenB that user repays (repay all -> type(uint).max)
    uint amtLPRepay; // Amount of LP that user repays (should be 0, now we support only borrowing based tokens).
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
  }

  constructor(IBankAVAX _bank, IPangolinFactory _factory) {
    bank = _bank;
    factory = _factory;
  }

  function openPosition(IPangolinSpellV2 _spell, AddLiquidityParams memory _params)
    external
    returns (uint positionId)
  {
    address lp = factory.getPair(_params.tokenA, _params.tokenB);

    // approve tokens
    ensureApprove(_params.tokenA, address(bank));
    ensureApprove(_params.tokenB, address(bank));
    ensureApprove(lp, address(bank));

    // transfer tokens from user
    IERC20(_params.tokenA).safeTransferFrom(msg.sender, address(this), _params.amtAUser);
    IERC20(_params.tokenB).safeTransferFrom(msg.sender, address(this), _params.amtBUser);
    IERC20(lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.addLiquidityWMiniChef.selector,
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
      _params.poolId
    );

    // (0 is reserved for opening new position)
    positionId = bank.execute(0, address(_spell), executeData);

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(lp);
  }

  function increasePosition(
    uint _positionId,
    IPangolinSpellV2 _spell,
    AddLiquidityParams memory _params
  ) external {
    address lp = factory.getPair(_params.tokenA, _params.tokenB);
    address rewardToken = getRewardToken(_positionId);

    // approve tokens
    ensureApprove(_params.tokenA, address(bank));
    ensureApprove(_params.tokenB, address(bank));
    ensureApprove(lp, address(bank));

    // transfer tokens from user
    IERC20(_params.tokenA).safeTransferFrom(msg.sender, address(this), _params.amtAUser);
    IERC20(_params.tokenB).safeTransferFrom(msg.sender, address(this), _params.amtBUser);
    IERC20(lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.addLiquidityWMiniChef.selector,
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
      _params.poolId
    );
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(lp);
    doRefund(rewardToken);
  }

  function reducePosition(
    uint _positionId,
    IPangolinSpellV2 _spell,
    RemoveLiquidityParams memory _params
  ) external {
    address lp = factory.getPair(_params.tokenA, _params.tokenB);
    address rewardToken = getRewardToken(_positionId);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.removeLiquidityWMiniChef.selector,
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
    );
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(lp);
    doRefund(rewardToken);
  }

  function harvestRewards(uint _positionId, IPangolinSpellV2 _spell) external {
    bank.execute(
      _positionId,
      address(_spell),
      abi.encodeWithSelector(_spell.harvestWMiniChefRewards.selector)
    );

    // find reward token address from wrapper
    address rewardToken = getRewardToken(_positionId);

    doRefund(rewardToken);
  }

  function getPendingRewards(uint _positionId) external view returns (uint pendingRewards) {
    // query position info from position id
    (, address collateralTokenAddress, uint collateralId, uint collateralAmount) = bank
      .getPositionInfo(_positionId);

    IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);
    IMiniChefV2PNG chef = IMiniChefV2PNG(wrapper.chef());

    // get info for calculating rewards
    (uint poolId, uint startRewardTokenPerShare) = wrapper.decodeId(collateralId);
    uint endRewardTokenPerShare = calculateAccRewardPerShareMinichef(chef, poolId);

    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;

    pendingRewards = (enReward > stReward) ? enReward - stReward : 0;
  }

  function calculateAccRewardPerShareMinichef(IMiniChefV2PNG _chef, uint _poolId)
    internal
    view
    returns (uint accRewardPerShare)
  {
    uint lastRewardTime;
    uint allocPoint;
    (accRewardPerShare, lastRewardTime, allocPoint) = _chef.poolInfo(_poolId);
    IERC20 lpToken = IERC20(_chef.lpToken(_poolId));
    uint lpSupply = lpToken.balanceOf(address(this));
    uint rewardsExpiration = _chef.rewardsExpiration();
    uint currentTimestamp = block.timestamp;
    uint totalAllocPoint = _chef.totalAllocPoint();
    uint rewardPerSecond = _chef.rewardPerSecond();

    if (currentTimestamp > lastRewardTime && lpSupply != 0) {
      uint time = currentTimestamp <= rewardsExpiration
        ? currentTimestamp - lastRewardTime // Accrue rewards until now
        : rewardsExpiration > lastRewardTime
        ? rewardsExpiration - lastRewardTime // Accrue rewards until expiration
        : 0; // No rewards to accrue
      uint reward = (time * rewardPerSecond * allocPoint) / totalAllocPoint;
      accRewardPerShare += (reward * PRECISION) / lpSupply;
    }
  }

  function getRewardToken(uint _positionId) internal view returns (address rewardToken) {
    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);

    // find reward token address from wrapper
    rewardToken = address(wrapper.png());
  }
}
