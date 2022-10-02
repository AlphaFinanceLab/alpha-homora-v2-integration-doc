// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../BaseIntegration.sol';
import '../utils/HomoraMath.sol';
import '../../interfaces/uniswapv3/IUniswapV3Factory.sol';
import '../../interfaces/uniswapv3/IUniswapV3Pool.sol';
import '../../interfaces/uniswapv3/IUniswapV3PositionManager.sol';
import '../../interfaces/homorav2/banks/IBankETH.sol';
import '../../interfaces/homorav2/wrappers/IWUniswapV3Position.sol';
import '../../interfaces/homorav2/spells/IUniswapV3Spell.sol';

import 'forge-std/console2.sol';

contract UniswapV3SpellIntegrationEth is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankETH bank; // homora bank
  IUniswapV3Factory factory; // uniswap v3 factory
  IUniswapV3PositionManager npm; // uniswap v3 position manager

  constructor(
    IBankETH _bank,
    IUniswapV3Factory _factory,
    IUniswapV3PositionManager _npm
  ) {
    bank = _bank;
    factory = _factory;
    npm = _npm;
  }

  function openPosition(IUniswapV3Spell _spell, IUniswapV3Spell.OpenPositionParams memory _params)
    external
    returns (uint positionId)
  {
    // approve tokens
    ensureApprove(_params.token0, address(bank));
    ensureApprove(_params.token1, address(bank));

    // transfer tokens from user
    IERC20(_params.token0).safeTransferFrom(msg.sender, address(this), _params.amt0User);
    IERC20(_params.token1).safeTransferFrom(msg.sender, address(this), _params.amt1User);

    bytes memory executeData = abi.encodeWithSelector(_spell.openPosition.selector, _params);
    // (0 is reserved for opening new position)
    positionId = bank.execute(0, address(_spell), executeData);
    doRefundETH();
    doRefund(_params.token0);
    doRefund(_params.token1);
  }

  function increasePosition(
    uint _positionId,
    IUniswapV3Spell _spell,
    IUniswapV3Spell.AddLiquidityParams memory _params
  ) external {
    (, address collateralTokenAddress, uint collateralTokenId, ) = bank.getPositionInfo(
      _positionId
    );
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper.getPositionInfoFromTokenId(
      collateralTokenId
    );

    // approve tokens
    ensureApprove(posInfo.token0, address(bank));
    ensureApprove(posInfo.token1, address(bank));

    // transfer tokens from user
    IERC20(posInfo.token0).safeTransferFrom(msg.sender, address(this), _params.amt0User);
    IERC20(posInfo.token1).safeTransferFrom(msg.sender, address(this), _params.amt1User);

    bytes memory executeData = abi.encodeWithSelector(_spell.addLiquidity.selector, _params);
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function reducePosition(
    uint _positionId,
    IUniswapV3Spell _spell,
    IUniswapV3Spell.RemoveLiquidityParams memory _params
  ) external {
    (, address collateralTokenAddress, uint collateralTokenId, ) = bank.getPositionInfo(
      _positionId
    );
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper.getPositionInfoFromTokenId(
      collateralTokenId
    );

    bytes memory executeData = abi.encodeWithSelector(_spell.removeLiquidity.selector, _params);
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function harvestFee(
    uint _positionId,
    IUniswapV3Spell _spell,
    bool _convertWETH
  ) external {
    bytes memory executeData = abi.encodeWithSelector(_spell.harvest.selector, _convertWETH);
    bank.execute(_positionId, address(_spell), executeData);

    // query position info from position id
    (, address collateralTokenAddress, uint collateralTokenId, ) = bank.getPositionInfo(
      _positionId
    );

    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);
    IWUniswapV3Position.PositionInfo memory posInfo = wrapper.getPositionInfoFromTokenId(
      collateralTokenId
    );

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function closePosition(
    uint _positionId,
    IUniswapV3Spell _spell,
    IUniswapV3Spell.ClosePositionParams memory _params
  ) external {
    (, address collateralTokenAddress, uint collateralId, ) = bank.getPositionInfo(_positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper.getPositionInfoFromTokenId(
      collateralId
    );

    bytes memory executeData = abi.encodeWithSelector(_spell.closePosition.selector, _params);
    bank.execute(_positionId, address(_spell), executeData);
    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function reinvest(
    uint _positionId,
    IUniswapV3Spell _spell,
    IUniswapV3Spell.ReinvestParams memory _params
  ) external {
    (, address collateralTokenAddress, uint collateralId, ) = bank.getPositionInfo(_positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper.getPositionInfoFromTokenId(
      collateralId
    );

    bytes memory executeData = abi.encodeWithSelector(_spell.reinvest.selector, _params);
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function getPendingFees(uint _positionId) external view returns (uint feeAmt0, uint feeAmt1) {
    uint collateralTokenId;
    uint collateralAmount;
    address collateralTokenAddress;
    uint feeGrowthInside0LastX128;
    uint feeGrowthInside1LastX128;
    IWUniswapV3Position.PositionInfo memory posInfo;
    IWUniswapV3Position wrapper;
    {
      // query position info from position id
      (, collateralTokenAddress, collateralTokenId, collateralAmount) = bank.getPositionInfo(
        _positionId
      );

      wrapper = IWUniswapV3Position(collateralTokenAddress);

      (, , , , , , , , feeGrowthInside0LastX128, feeGrowthInside1LastX128, , ) = npm.positions(
        collateralTokenId
      );

      posInfo = wrapper.getPositionInfoFromTokenId(collateralTokenId);
    }
    IUniswapV3Pool pool = IUniswapV3Pool(
      factory.getPool(posInfo.token0, posInfo.token1, posInfo.fee)
    );
    (, int24 curTick, , , , , ) = pool.slot0();

    (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(
      _getPositionID(address(npm), posInfo.tickLower, posInfo.tickUpper)
    );

    feeAmt0 =
      _computeFeesEarned(
        pool,
        true,
        feeGrowthInside0LastX128,
        curTick,
        posInfo.tickLower,
        posInfo.tickUpper,
        liquidity
      ) +
      tokensOwed0;
    feeAmt1 =
      _computeFeesEarned(
        pool,
        false,
        feeGrowthInside1LastX128,
        curTick,
        posInfo.tickLower,
        posInfo.tickUpper,
        liquidity
      ) +
      tokensOwed1;
  }

  function _getPositionID(
    address _owner,
    int24 _lowerTick,
    int24 _upperTick
  ) internal pure returns (bytes32 positionId) {
    return keccak256(abi.encodePacked(_owner, _lowerTick, _upperTick));
  }

  // ref: from arrakis finance: https://github.com/ArrakisFinance/vault-v1-core/blob/main/contracts/ArrakisVaultV1.sol
  function _computeFeesEarned(
    IUniswapV3Pool _pool,
    bool _isZero,
    uint _feeGrowthInsideLast,
    int24 _tick,
    int24 _lowerTick,
    int24 _upperTick,
    uint128 _liquidity
  ) internal view returns (uint fee) {
    uint feeGrowthOutsideLower;
    uint feeGrowthOutsideUpper;
    uint feeGrowthGlobal;
    if (_isZero) {
      feeGrowthGlobal = _pool.feeGrowthGlobal0X128();
      (, , feeGrowthOutsideLower, , , , , ) = _pool.ticks(_lowerTick);
      (, , feeGrowthOutsideUpper, , , , , ) = _pool.ticks(_upperTick);
    } else {
      feeGrowthGlobal = _pool.feeGrowthGlobal1X128();
      (, , , feeGrowthOutsideLower, , , , ) = _pool.ticks(_lowerTick);
      (, , , feeGrowthOutsideUpper, , , , ) = _pool.ticks(_upperTick);
    }

    unchecked {
      // calculate fee growth below
      uint feeGrowthBelow;
      if (_tick >= _lowerTick) {
        feeGrowthBelow = feeGrowthOutsideLower;
      } else {
        feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
      }

      // calculate fee growth above
      uint feeGrowthAbove;
      if (_tick < _upperTick) {
        feeGrowthAbove = feeGrowthOutsideUpper;
      } else {
        feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
      }

      uint feeGrowthInside = feeGrowthGlobal - feeGrowthBelow - feeGrowthAbove;
      fee = (_liquidity * (feeGrowthInside - _feeGrowthInsideLast)) / 2**128;
    }
  }
}
