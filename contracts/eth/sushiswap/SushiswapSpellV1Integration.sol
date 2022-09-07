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

import '../../../../interfaces/eth/sushiswap/ISushiswapFactory.sol';

import 'forge-std/console2.sol';

contract SushiswapSpellV1Integration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankETH bank; // homora bank
  ISushiswapFactory factory; // sushi swap factory

  // addLiquidityWERC20(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256))
  bytes4 addLiquidityWERC20Selector = 0xcc9b1880;

  // addLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256),uint256)
  bytes4 addLiquidityWMasterChefSelector = 0xe07d904e;

  // removeLiquidityWERC20(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))
  bytes4 removeLiquidityWERC20Selector = 0x1387d96d;

  // removeLiquidityWMasterChef(address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256))
  bytes4 removeLiquidityWMasterChefSelector = 0x95723b1c;

  // harvestWMasterChef()
  bytes4 harvestRewardsSelector = 0x40a65ad2;
  uint constant PRECISION = 10**12;

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

  constructor(IBankETH _bank, ISushiswapFactory _factory) {
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
        addLiquidityWMasterChefSelector, // FIXME: change selector to addLiquidityWERC20Selector for liquidity providing
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
        addLiquidityWMasterChefSelector, // FIXME: change selector to addLiquidityWERC20Selector for liquidity providing
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
        removeLiquidityWMasterChefSelector, // FIXME: change selector to removeLiquidityWERC20Selector for liquidity providing
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
    doRefund(rewardToken);
    doRefund(lp);
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

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);
    IMasterChef chef = IMasterChef(wrapper.chef());

    // get info for calculating rewards
    (uint pid, uint startRewardTokenPerShare) = wrapper.decodeId(collateralId);
    uint endRewardTokenPerShare = calculateAccRewardPerShareChef(chef, pid);

    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;

    pendingRewards = (enReward > stReward) ? enReward - stReward : 0;
  }

  function calculateAccRewardPerShareChef(IMasterChef _chef, uint _pid)
    internal
    view
    returns (uint accSushiPerShare)
  {
    address lpToken;
    uint allocPoint;
    uint lastRewardBlock;
    (lpToken, allocPoint, lastRewardBlock, accSushiPerShare) = _chef.poolInfo(_pid);
    if (block.number <= lastRewardBlock) {
      return accSushiPerShare;
    }
    uint lpSupply = IERC20(lpToken).balanceOf(address(_chef));
    if (lpSupply == 0) {
      lastRewardBlock = block.number;
      return accSushiPerShare;
    }
    uint multiplier = _chef.getMultiplier(lastRewardBlock, block.number);
    uint sushiReward = (multiplier * _chef.sushiPerBlock() * allocPoint) / _chef.totalAllocPoint();
    accSushiPerShare += ((sushiReward * PRECISION) / lpSupply);
  }

  function getRewardToken(uint _positionId) internal view returns (address rewardToken) {
    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);

    // find reward token address from wrapper
    rewardToken = address(wrapper.sushi());
  }
}
