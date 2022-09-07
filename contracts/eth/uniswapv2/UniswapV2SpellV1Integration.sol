// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../../BaseIntegration.sol';
import '../../utils/HomoraMath.sol';

import '../../../../interfaces/eth/IBankETH.sol';
import '../../../../interfaces/eth/uniswapv2/IWStakingRewards.sol';
import '../../../../interfaces/eth/uniswapv2/IStakingRewards.sol';
import '../../../../interfaces/eth/uniswapv2/IUniswapV2SpellV1.sol';
import '../../../../interfaces/eth/uniswapv2/IUniswapV2Factory.sol';

import 'forge-std/console2.sol';

contract UniswapV2SpellV1Integration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankETH bank; // homora bank
  IUniswapV2Factory factory; // uniswapv2 factory

  // addLiquidityWERC20(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256))
  bytes4 addLiquidityWERC20Selector = 0xcc9b1880;

  // addLiquidityWStakingRewards(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256),address)
  bytes4 addLiquidityWStkaingRewardsSelector = 0xd57cdec5;

  // removeLiquidityWERC20(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))
  bytes4 removeLiquidityWERC20Selector = 0x1387d96d;

  // removeLiquidityWStakingRewards(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256),address)
  bytes4 removeLiquidityWStakingRewardsSelector = 0xb2cfde44;

  // harvestWStakingRewards(address)
  bytes4 harvestRewardsSelector = 0x45174f18;
  uint constant PRECISION = 10**18;

  struct AddLiquidityParams {
    address tokenA; // The first token of pool
    address tokenB; // The second token of pool
    uint amtAUser; // Supplied tokenA amount
    uint amtBUser; // Supplied tokenB amount
    uint amtLPUser; // Supplied LP token amount
    uint amtABorrow; // Borrow tokenA amount
    uint amtBBorrow; // Borrow tokenB amount
    uint amtLPBorrow; // Borrow LP token amount
    uint amtAMin; // Desired tokenA amount (slippage control)
    uint amtBMin; // Desired tokenB amount (slippage control)
    address wstaking; // WStaking address
  }

  struct RemoveLiquidityParams {
    address tokenA; // The first token of pool
    address tokenB; // The second token of pool
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to tokenA, tokenB)
    uint amtARepay; // Repay tokenA amount
    uint amtBRepay; // Repay tokenB amount
    uint amtLPRepay; // Repay LP token amount
    uint amtAMin; // Desired tokenA amount
    uint amtBMin; // Desired tokenB amount
    address wstaking; // WStaking address
  }

  constructor(IBankETH _bank, IUniswapV2Factory _factory) {
    bank = _bank;
    factory = _factory;
  }

  function openPosition(address _spell, AddLiquidityParams memory _params)
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

    positionId = bank.execute(
      0, // (0 is reserved for opening new position)
      _spell,
      abi.encodeWithSelector(
        addLiquidityWStkaingRewardsSelector, // FIXME: change selector to addLiquidityWERC20Selector for liquidity providing
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
      )
    );

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(lp);
  }

  function increasePosition(
    uint _positionId,
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
    IERC20(_params.tokenA).safeTransferFrom(msg.sender, address(this), _params.amtAUser);
    IERC20(_params.tokenB).safeTransferFrom(msg.sender, address(this), _params.amtBUser);
    IERC20(lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(
        addLiquidityWStkaingRewardsSelector, // FIXME: change selector to addLiquidityWERC20Selector for liquidity providing
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
    uint _positionId,
    RemoveLiquidityParams memory _params
  ) external {
    address lp = factory.getPair(_params.tokenA, _params.tokenB);
    address rewardToken = getRewardToken(_positionId);

    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(
        removeLiquidityWStakingRewardsSelector, // FIXME: change selector to removeLiquidityWERC20Selector for liquidity providing
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
      )
    );

    doRefundETH();
    doRefund(_params.tokenA);
    doRefund(_params.tokenB);
    doRefund(rewardToken);
    doRefund(lp);
  }

  function harvestRewards(
    address _spell,
    uint _positionId,
    address wstaking
  ) external {
    bank.execute(_positionId, _spell, abi.encodeWithSelector(harvestRewardsSelector, wstaking));

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
