// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../../BaseIntegration.sol';
import '../../utils/HomoraMath.sol';

import '../../../../interfaces/eth/IBankETH.sol';
import '../../../../interfaces/eth/sushiswap/IWMasterChef.sol';
import '../../../../interfaces/eth/sushiswap/IMasterChef.sol';
import '../../../../interfaces/eth/sushiswap/ISushiswapSpellV1.sol';

import '../../../../interfaces/eth/uniswapv2/IUniswapV2Factory.sol';

import 'forge-std/console2.sol';

contract SushiswapSpellV1Integration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankETH bank; // homora bank
  IUniswapV2Factory factory; // sushi swap factory

  // addLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256),uint256)
  bytes4 addLiquiditySelector = 0xe07d904e;

  // removeLiquidityWERC20(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))
  bytes4 removeLiquiditySelector = 0x1387d96d;

  // harvestWMasterChef()
  bytes4 harvestRewardsSelector = 0x40a65ad2;
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
    uint pid; // pool id of MasterChef
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
        addLiquiditySelector,
        _params.tokenA,
        _params.tokenB,
        ISushiswapSpellV1.Amounts(
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
    uint _positionId,
    address _spell,
    AddLiquidityParams memory _params
  ) external {
    address lp = factory.getPair(_params.tokenA, _params.tokenB);

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
        addLiquiditySelector,
        _params.tokenA,
        _params.tokenB,
        ISushiswapSpellV1.Amounts(
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
    uint _positionId,
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
        ISushiswapSpellV1.RepayAmounts(
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

  function harvestRewards(address _spell, uint _positionId) external {
    bank.execute(_positionId, _spell, abi.encodeWithSelector(harvestRewardsSelector));

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);

    // find reward token address from wrapper
    address rewardToken = address(wrapper.sushi());

    doRefund(rewardToken);
  }

  function getPendingRewards(uint _positionId) external view returns (uint pendingRewards) {
    // query position info from position id
    (, address collateralTokenAddress, uint collateralId, uint collateralAmount) = bank
      .getPositionInfo(_positionId);

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);
    IMasterChef chef = IMasterChef(wrapper.chef());

    // get info for calculating rewards
    (uint pid, uint startRewardTokenPerShare) = wrapper.decodeId(collateralId);
    (, , , uint endRewardTokenPerShare) = chef.poolInfo(pid);
    (uint totalSupply, ) = chef.userInfo(pid, address(wrapper)); // total lp from wrapper deposited in Chef

    // pending rewards separates into two parts
    // 1. pending rewards that are in the wrapper contract
    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;
    uint userPendingRewardsFromWrapper = (enReward > stReward) ? enReward - stReward : 0;

    // 2. pending rewards that wrapper hasn't claimed from Chef's contract
    uint pendingRewardFromChef = chef.pendingSushi(pid, address(wrapper));
    uint userPendingRewardFromChef = (collateralAmount * pendingRewardFromChef) / totalSupply;

    pendingRewards = userPendingRewardsFromWrapper + userPendingRewardFromChef;
  }
}
