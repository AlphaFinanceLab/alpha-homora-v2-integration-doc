// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../BaseIntegration.sol';
import '../utils/HomoraMath.sol';

import '../../interfaces/uniswapv2/IStakingRewards.sol';
import '../../interfaces/uniswapv2/IUniswapV2Factory.sol';
import '../../interfaces/homorav2/banks/IBankETH.sol';
import '../../interfaces/homorav2/wrappers/IWStakingRewards.sol';
import '../../interfaces/homorav2/spells/IUniswapV2SpellV1.sol';

import 'forge-std/console2.sol';

contract UniswapV2SpellV1IntegrationEth is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankETH bank; // homora bank
  IUniswapV2Factory factory; // uniswapv2 factory
  uint constant PRECISION = 10**18;

  struct AddLiquidityParams {
    address tokenA; // The first token of pool
    address tokenB; // The second token of pool
    uint amtAUser; // Supplied tokenA amount
    uint amtBUser; // Supplied tokenB amount
    uint amtLPUser; // Supplied LP token amount
    uint amtABorrow; // Borrow tokenA amount
    uint amtBBorrow; // Borrow tokenB amount
    uint amtLPBorrow; // Borrow LP token amount (should be 0, not support borrowing LP tokens)
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
    address wstaking; // WStaking address
  }

  struct RemoveLiquidityParams {
    address tokenA; // The first token of pool
    address tokenB; // The second token of pool
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP that user receives (remainings are converted to underlying tokens).
    uint amtARepay; // Amount of tokenA that user repays (repay all -> type(uint).max)
    uint amtBRepay; // Amount of tokenB that user repays (repay all -> type(uint).max)
    uint amtLPRepay; // Amount of LP that user repays (should be 0, not support borrowing LP tokens).
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
    address wstaking; // WStaking address
  }

  constructor(IBankETH _bank, IUniswapV2Factory _factory) {
    bank = _bank;
    factory = _factory;
  }

  function openPositionWStaking(IUniswapV2SpellV1 _spell, AddLiquidityParams memory _params)
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
      _spell.addLiquidityWStakingRewards.selector,
      _params.tokenA,
      _params.tokenB,
      IUniswapV2SpellV1.Amounts(
        _params.amtAUser,
        _params.amtBUser,
        _params.amtLPUser,
        _params.amtABorrow,
        _params.amtBBorrow,
        _params.amtLPBorrow,
        _params.amtAMin,
        _params.amtBMin
      ),
      _params.wstaking
    );
    // (0 is reserved for opening new position)
    positionId = bank.execute(0, address(_spell), executeData);

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(lp);
  }

  function increasePositionWStaking(
    uint _positionId,
    IUniswapV2SpellV1 _spell,
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
      _spell.addLiquidityWStakingRewards.selector,
      _params.tokenA,
      _params.tokenB,
      IUniswapV2SpellV1.Amounts(
        _params.amtAUser,
        _params.amtBUser,
        _params.amtLPUser,
        _params.amtABorrow,
        _params.amtBBorrow,
        _params.amtLPBorrow,
        _params.amtAMin,
        _params.amtBMin
      ),
      _params.wstaking
    );
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(lp);
    doRefund(rewardToken);
  }

  function reducePositionWStaking(
    uint _positionId,
    IUniswapV2SpellV1 _spell,
    RemoveLiquidityParams memory _params
  ) external {
    address lp = factory.getPair(_params.tokenA, _params.tokenB);
    address rewardToken = getRewardToken(_positionId);
    bytes memory executeData = abi.encodeWithSelector(
      _spell.removeLiquidityWStakingRewards.selector,
      _params.tokenA,
      _params.tokenB,
      IUniswapV2SpellV1.RepayAmounts(
        _params.amtLPTake,
        _params.amtLPWithdraw,
        _params.amtARepay,
        _params.amtBRepay,
        _params.amtLPRepay,
        _params.amtAMin,
        _params.amtBMin
      ),
      _params.wstaking
    );
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(rewardToken);
    doRefund(lp);
  }

  function harvestRewardsWStaking(
    uint _positionId,
    IUniswapV2SpellV1 _spell,
    address wstaking
  ) external {
    bytes memory executeData = abi.encodeWithSelector(
      _spell.harvestWStakingRewards.selector,
      wstaking
    );
    bank.execute(_positionId, address(_spell), executeData);

    address rewardToken = getRewardToken(_positionId);
    doRefund(rewardToken);
  }

  function getPendingRewards(uint _positionId) external view returns (uint pendingRewards) {
    // query position info from position id
    (, address collateralTokenAddress, uint collateralId, uint collateralAmount) = bank
      .getPositionInfo(_positionId);

    IWStakingRewards wrapper = IWStakingRewards(collateralTokenAddress);
    IStakingRewards staking = IStakingRewards(wrapper.staking());

    // get info for calculating rewards
    uint startRewardTokenPerShare = collateralId;
    uint endRewardTokenPerShare = staking.rewardPerToken();
    uint totalSupply = staking.balanceOf(address(wrapper)); // total lp deposited in staking rewards

    // pending rewards separates into two parts
    // 1. pending rewards that are in the wrapper contract
    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;
    uint userPendingRewardsFromWrapper = (enReward > stReward) ? enReward - stReward : 0;

    // 2. pending rewards that wrapper hasn't claimed from Staking's contract
    uint pendingRewardFromStaking = staking.earned(address(wrapper));
    uint userPendingRewardFromStaking = (collateralAmount * pendingRewardFromStaking) / totalSupply;

    pendingRewards = userPendingRewardsFromWrapper + userPendingRewardFromStaking;
  }

  function getRewardToken(uint _positionId) internal view returns (address rewardToken) {
    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWStakingRewards wrapper = IWStakingRewards(collateralTokenAddress);

    // find reward token address from wrapper
    rewardToken = address(wrapper.reward());
  }
}
