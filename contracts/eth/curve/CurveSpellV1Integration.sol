// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../../BaseIntegration.sol';
import '../../utils/HomoraMath.sol';

import '../../../interfaces/eth/IBankETH.sol';
import '../../../interfaces/eth/curve/ICurveRegistry.sol';
import '../../../interfaces/eth/curve/ICurveSpellV1.sol';
import '../../../interfaces/eth/curve/IWLiquidityGauge.sol';

import 'forge-std/console2.sol';

contract CurveSpellV1Integration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankETH bank; // homora bank
  ICurveRegistry registry; // sushi swap factory

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

  function openPosition(ICurveSpellV1 _spell, AddLiquidity3Params memory _params)
    external
    returns (uint positionId)
  {
    require(_params.amtsUser.length == _params.amtsBorrow.length, 'amount length mismatched');

    address pool = registry.get_pool_from_lp_token(_params.lp);
    (uint n, ) = registry.get_n_coins(pool);
    require(n == 3, 'not support');
    require(_params.amtsUser.length == n, 'not n');

    address[8] memory tokens = registry.get_coins(pool);

    // approve and transfer tokens
    for (uint i = 0; i < n; i++) {
      ensureApprove(tokens[i], address(bank));
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    ensureApprove(_params.lp, address(bank));
    IERC20(_params.lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.addLiquidity3.selector,
      _params.lp,
      _params.amtsUser,
      _params.amtLPUser,
      _params.amtsBorrow,
      _params.amtLPBorrow,
      _params.minLPMint,
      _params.pid,
      _params.gid
    );
    // (0 is reserved for opening new position)
    positionId = bank.execute(0, address(_spell), executeData);

    for (uint i = 0; i < n; i++) doRefund(tokens[i]);
    doRefund(_params.lp);
    doRefund(crv);
  }

  function increasePosition(
    uint _positionId,
    ICurveSpellV1 _spell,
    AddLiquidity3Params memory _params
  ) external {
    address pool = registry.get_pool_from_lp_token(_params.lp);
    (uint n, ) = registry.get_n_coins(pool);
    require(n == 3, 'not support');
    require(_params.amtsUser.length == n, 'not n');
    address[8] memory tokens = registry.get_coins(pool);

    // approve and transfer tokens
    for (uint i = 0; i < n; i++) {
      ensureApprove(tokens[i], address(bank));
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    ensureApprove(_params.lp, address(bank));
    IERC20(_params.lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.addLiquidity3.selector,
      _params.lp,
      _params.amtsUser,
      _params.amtLPUser,
      _params.amtsBorrow,
      _params.amtLPBorrow,
      _params.minLPMint,
      _params.pid,
      _params.gid
    );
    bank.execute(_positionId, address(_spell), executeData);

    for (uint i = 0; i < n; i++) doRefund(tokens[i]);
    doRefund(crv);
  }

  function reducePosition(
    uint _positionId,
    ICurveSpellV1 _spell,
    RemoveLiquidity3Params memory _params
  ) external {
    address pool = registry.get_pool_from_lp_token(_params.lp);
    (uint n, ) = registry.get_n_coins(pool);
    require(_params.amtsRepay.length == n, 'amtsRepay.length not n');
    require(_params.amtsMin.length == n, 'amtsMin.length not n');
    require(n == 3, 'not support');

    address[8] memory tokens = registry.get_coins(pool);
    bytes memory executeData = abi.encodeWithSelector(
      _spell.removeLiquidity3.selector,
      _params.lp,
      _params.amtLPTake,
      _params.amtLPWithdraw,
      _params.amtsRepay,
      _params.amtLPRepay,
      _params.amtsMin
    );
    bank.execute(_positionId, address(_spell), executeData);

    for (uint i = 0; i < n; i++) doRefund(tokens[i]);
    doRefund(_params.lp);
    doRefund(crv);
  }

  function harvestRewards(uint _positionId, ICurveSpellV1 _spell) external {
    bank.execute(_positionId, address(_spell), abi.encodeWithSelector(_spell.harvest.selector));
    doRefund(crv);
  }

  function getPendingRewards(uint _positionId) external returns (uint pendingRewards) {
    // query position info from position id
    (, address collateralTokenAddress, uint collateralId, uint collateralAmount) = bank
      .getPositionInfo(_positionId);

    IWLiquidityGauge wrapper = IWLiquidityGauge(collateralTokenAddress);

    // get info for calculating rewards
    (uint pid, uint gid, uint startRewardTokenPerShare) = wrapper.decodeId(collateralId);

    (address gauge, uint endRewardTokenPerShare) = wrapper.gauges(pid, gid);
    uint totalSupply = IERC20(gauge).balanceOf(address(wrapper)); // total gauge share of wrapper

    // pending rewards separates into two parts
    // 1. pending rewards that are in the wrapper contract
    // 2. pending rewards that wrapper hasn't claimed from Gauge's contract
    uint pendingRewardFromGauge = ILiquidityGauge(gauge).claimable_tokens(address(wrapper));
    endRewardTokenPerShare += (pendingRewardFromGauge * PRECISION) / totalSupply;

    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;

    pendingRewards = (enReward > stReward) ? enReward - stReward : 0;
  }
}
