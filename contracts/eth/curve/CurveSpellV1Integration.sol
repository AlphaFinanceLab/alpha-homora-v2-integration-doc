// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../../BaseIntegration.sol';
import '../../utils/HomoraMath.sol';

import '../../../../interfaces/eth/IBankETH.sol';
import '../../../../interfaces/eth/curve/ICurveRegistry.sol';
import '../../../../interfaces/eth/curve/IWLiquidityGauge.sol';

import 'forge-std/console2.sol';

contract CurveSpellV1Integration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankETH bank; // homora bank
  ICurveRegistry registry; // sushi swap factory

  // addLiquidity2(address,uint256[2],uint256,uint256[2],uint256,uint256,uint256,uint256)
  bytes4 addLiquidity2Selector = 0x9a323470;

  // addLiquidity3(address,uint256[3],uint256,uint256[3],uint256,uint256,uint256,uint256)
  bytes4 addLiquidity3Selector = 0xbe0ca465;

  // addLiquidity4(address,uint256[4],uint256,uint256[4],uint256,uint256,uint256,uint256)
  bytes4 addLiquidity4Selector = 0xc3d34ea1;

  // removeLiquidity2(address,uint256,uint256,uint256[2],uint256,uint256[2])
  bytes4 removeLiquidity2Selector = 0xf9c61fb7;

  // removeLiquidity3(address,uint256,uint256,uint256[3],uint256,uint256[3])
  bytes4 removeLiquidity3Selector = 0xce26f242;

  // removeLiquidity4(address,uint256,uint256,uint256[4],uint256,uint256[4])
  bytes4 removeLiquidity4Selector = 0xe81667ea;

  // harvest()
  bytes4 harvestRewardsSelector = 0x4641257d;

  uint constant PRECISION = 10**18;
  address public crv;

  struct AddLiquidity3Params {
    address lp; // LP token for the pool
    uint[3] amtsUser; // Supplied underlying token amounts
    uint amtLPUser; // Supplied LP token amount
    uint[3] amtsBorrow; // Borrow underlying token amounts
    uint amtLPBorrow; // Borrow LP token amount
    uint minLPMint; // Desired LP token amount (slippage control)
    uint pid; // Curve pool id for the pool
    uint gid; // Curve gauge id for the pool
  }

  struct RemoveLiquidity3Params {
    address lp; // LP token for the pool
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP being received from removing the position (remaining will be converted to each tokens)
    uint[3] amtsRepay; // Repay tokens amount (repay all -> type(uint).max)
    uint amtLPRepay; // Repay LP token amount
    uint[3] amtsMin; // Desired underlying token amounts (slippage control)
  }

  constructor(
    IBankETH _bank,
    ICurveRegistry _registry,
    address _crv
  ) {
    bank = _bank;
    registry = _registry;
    crv = _crv;
  }

  function openPosition(address _spell, AddLiquidity3Params memory _params)
    external
    returns (uint positionId)
  {
    require(_params.amtsUser.length == _params.amtsBorrow.length, 'amount length mismatched');

    address pool = registry.get_pool_from_lp_token(_params.lp);
    (uint n, ) = registry.get_n_coins(pool);
    require(_params.amtsUser.length == n, 'not n');

    address[8] memory tokens = registry.get_coins(pool);

    // approve and transfer tokens
    for (uint i = 0; i < n; i++) {
      ensureApprove(tokens[i], address(bank));
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    ensureApprove(_params.lp, address(bank));
    IERC20(_params.lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes4 addLiquiditySelector;
    if (n == 2) {
      addLiquiditySelector = addLiquidity2Selector;
    } else if (n == 3) {
      addLiquiditySelector = addLiquidity3Selector;
    } else if (n == 4) {
      addLiquiditySelector = addLiquidity4Selector;
    } else {
      revert('not support');
    }

    positionId = bank.execute(
      0, // (0 is reserved for opening new position)
      _spell,
      abi.encodeWithSelector(
        addLiquiditySelector,
        _params.lp,
        _params.amtsUser,
        _params.amtLPUser,
        _params.amtsBorrow,
        _params.amtLPBorrow,
        _params.minLPMint,
        _params.pid,
        _params.gid
      )
    );

    for (uint i = 0; i < n; i++) doRefund(tokens[i]);
    doRefund(_params.lp);
    doRefund(crv);
  }

  function increasePosition(
    uint _positionId,
    address _spell,
    AddLiquidity3Params memory _params
  ) external {
    address pool = registry.get_pool_from_lp_token(_params.lp);
    (uint n, ) = registry.get_n_coins(pool);
    address[8] memory tokens = registry.get_coins(pool);

    // approve and transfer tokens
    for (uint i = 0; i < n; i++) {
      ensureApprove(tokens[i], address(bank));
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    ensureApprove(_params.lp, address(bank));
    IERC20(_params.lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes4 addLiquiditySelector;
    if (n == 2) {
      addLiquiditySelector = addLiquidity2Selector;
    } else if (n == 3) {
      addLiquiditySelector = addLiquidity3Selector;
    } else if (n == 4) {
      addLiquiditySelector = addLiquidity4Selector;
    } else {
      revert('not suport');
    }

    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(
        addLiquiditySelector,
        _params.lp,
        _params.amtsUser,
        _params.amtLPUser,
        _params.amtsBorrow,
        _params.amtLPBorrow,
        _params.minLPMint,
        _params.pid,
        _params.gid
      )
    );

    for (uint i = 0; i < n; i++) doRefund(tokens[i]);
    doRefund(crv);
  }

  function reducePosition(
    address _spell,
    uint _positionId,
    RemoveLiquidity3Params memory _params
  ) external {
    address pool = registry.get_pool_from_lp_token(_params.lp);
    (uint n, ) = registry.get_n_coins(pool);
    require(_params.amtsRepay.length == n);
    require(_params.amtsMin.length == n);

    address[8] memory tokens = registry.get_coins(pool);

    bytes4 removeLiquiditySelector;
    if (n == 2) {
      removeLiquiditySelector = removeLiquidity2Selector;
    } else if (n == 3) {
      removeLiquiditySelector = removeLiquidity3Selector;
    } else if (n == 4) {
      removeLiquiditySelector = removeLiquidity4Selector;
    }

    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(
        removeLiquiditySelector,
        _params.lp,
        _params.amtLPTake,
        _params.amtLPWithdraw,
        _params.amtsRepay,
        _params.amtLPRepay,
        _params.amtsMin
      )
    );

    for (uint i = 0; i < n; i++) doRefund(tokens[i]);
    doRefund(_params.lp);
    doRefund(crv);
  }

  function harvestRewards(address _spell, uint _positionId) external {
    bank.execute(_positionId, _spell, abi.encodeWithSelector(harvestRewardsSelector));

    doRefund(crv);
  }

  function getPendingRewards(uint _positionId) external returns (uint pendingRewards) {
    // query position info from position id
    (, address collateralTokenAddress, uint collateralId, uint collateralAmount) = bank
      .getPositionInfo(_positionId);

    IWLiquidityGauge wrapper = IWLiquidityGauge(collateralTokenAddress);

    // get info for calculating rewards
    (uint pid, uint gid, uint startRewardTokenPerShare) = wrapper.decodeId(collateralId);

    address lp = wrapper.getUnderlyingTokenFromIds(pid, gid);
    (address gauge, uint endRewardTokenPerShare) = wrapper.gauges(pid, gid);
    uint totalSupply = IERC20(gauge).balanceOf(address(wrapper)); // total gauge share of wrapper

    // pending rewards separates into two parts
    // 1. pending rewards that are in the wrapper contract
    // 2. pending rewards that wrapper hasn't claimed from Chef's contract
    uint pendingRewardFromGauge = ILiquidityGauge(gauge).claimable_tokens(address(wrapper));
    endRewardTokenPerShare += (pendingRewardFromGauge * PRECISION) / totalSupply;

    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;

    pendingRewards = (enReward > stReward) ? enReward - stReward : 0;
  }
}
