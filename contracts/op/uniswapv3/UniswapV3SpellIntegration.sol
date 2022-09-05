// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../BaseIntegration.sol";
import "../../utils/HomoraMath.sol";
import "../../../../interfaces/op/IBankOP.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3Factory.sol";
import "../../../../interfaces/op/uniswapv3/IWUniswapV3Position.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3Pool.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3PositionManager.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3Spell.sol";
import "forge-std/console2.sol";

contract UniswapV3SpellIntegration is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint256;

  IBankOP bank; // homora bank
  IUniswapV3Factory factory; // uniswap v3 factory
  IUniswapV3PositionManager npm; // uniswap v3 position manager

  // openPosition((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,uint256))
  bytes4 openPositionSelector = 0xbd0ce28c;

  // addLiquidity((uint,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,uint256))
  bytes4 addLiquiditySelector = 0x46f9ad4d;

  // removeLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))
  bytes4 removeLiquiditySelector = 0x49d9a738;

  // harvest(bool)
  bytes4 harvestFeeSelector = 0x70a1903d;

  // closePosition((uint256,uint256,uint256,bool))
  bytes4 closePositionSelector = 0x713866c9;

  // reinvest((uint256,uint256,bool,uint256,uint256,uint256))
  bytes4 reinvestSelector = 0x5d12ab7e;

  constructor(
    IBankOP _bank,
    IUniswapV3Factory _factory,
    IUniswapV3PositionManager _npm
  ) {
    bank = _bank;
    factory = _factory;
    npm = _npm;
  }

  function openPosition(
    address _spell,
    IUniswapV3Spell.OpenPositionParams memory _params
  ) external returns (uint256 positionId) {
    // approve tokens
    ensureApprove(_params.token0, address(bank));
    ensureApprove(_params.token1, address(bank));

    // transfer tokens from user
    IERC20(_params.token0).safeTransferFrom(
      msg.sender,
      address(this),
      _params.amt0User
    );
    IERC20(_params.token1).safeTransferFrom(
      msg.sender,
      address(this),
      _params.amt1User
    );

    positionId = bank.execute(
      0, // (0 is reserved for opening new position)
      _spell,
      abi.encodeWithSelector(openPositionSelector, _params)
    );

    doRefundETH();
    doRefund(_params.token0);
    doRefund(_params.token1);
  }

  function increasePosition(
    uint256 _positionId,
    address _spell,
    IUniswapV3Spell.AddLiquidityParams memory _params
  ) external {
    (, address collateralTokenAddress, uint256 collateralTokenId, ) = bank
      .getPositionInfo(_positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralTokenId);

    // approve tokens
    ensureApprove(posInfo.token0, address(bank));
    ensureApprove(posInfo.token1, address(bank));

    // transfer tokens from user
    IERC20(posInfo.token0).safeTransferFrom(
      msg.sender,
      address(this),
      _params.amt0User
    );
    IERC20(posInfo.token1).safeTransferFrom(
      msg.sender,
      address(this),
      _params.amt1User
    );
    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(addLiquiditySelector, _params)
    );

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function reducePosition(
    address _spell,
    uint256 _positionId,
    IUniswapV3Spell.RemoveLiquidityParams memory _params
  ) external {
    (, address collateralTokenAddress, uint256 collateralTokenId, ) = bank
      .getPositionInfo(_positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralTokenId);

    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(removeLiquiditySelector, _params)
    );

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function harvestFee(
    address _spell,
    uint256 _positionId,
    bool _convertWETH
  ) external {
    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(harvestFeeSelector, _convertWETH)
    );

    // query position info from position id
    (, address collateralTokenAddress, uint256 collateralTokenId, ) = bank
      .getPositionInfo(_positionId);

    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);
    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralTokenId);

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function closePosition(
    address _spell,
    uint256 _positionId,
    IUniswapV3Spell.ClosePositionParams memory _params
  ) external {
    (, address collateralTokenAddress, uint256 collateralId, ) = bank
      .getPositionInfo(_positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralId);

    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(closePositionSelector, _params)
    );
    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function reinvest(
    address _spell,
    uint256 _positionId,
    IUniswapV3Spell.ReinvestParams memory _params
  ) external {
    (, address collateralTokenAddress, uint256 collateralId, ) = bank
      .getPositionInfo(_positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralId);

    bank.execute(
      _positionId,
      _spell,
      abi.encodeWithSelector(reinvestSelector, _params)
    );

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  // ref: from arrakis finance: https://github.com/ArrakisFinance/vault-v1-core/blob/main/contracts/ArrakisVaultV1.sol
  function _computeFeesEarned(
    IUniswapV3Pool _pool,
    bool _isZero,
    uint256 _feeGrowthInsideLast,
    int24 _tick,
    int24 _lowerTick,
    int24 _upperTick,
    uint128 _liquidity
  ) private view returns (uint256 fee) {
    uint256 feeGrowthOutsideLower;
    uint256 feeGrowthOutsideUpper;
    uint256 feeGrowthGlobal;
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
      uint256 feeGrowthBelow;
      if (_tick >= _lowerTick) {
        feeGrowthBelow = feeGrowthOutsideLower;
      } else {
        feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
      }

      // calculate fee growth above
      uint256 feeGrowthAbove;
      if (_tick < _upperTick) {
        feeGrowthAbove = feeGrowthOutsideUpper;
      } else {
        feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
      }

      uint256 feeGrowthInside = feeGrowthGlobal -
        feeGrowthBelow -
        feeGrowthAbove;
      fee = (_liquidity * (feeGrowthInside - _feeGrowthInsideLast)) / 2**128;
    }
  }

  function _getPositionID(
    address _owner,
    int24 _lowerTick,
    int24 _upperTick
  ) internal view returns (bytes32 positionId) {
    return keccak256(abi.encodePacked(_owner, _lowerTick, _upperTick));
  }

  function getPendingFees(uint256 _positionId)
    external
    returns (uint256 feeAmt0, uint256 feeAmt1)
  {
    uint256 collateralTokenId;
    uint256 collateralAmount;
    address collateralTokenAddress;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    IWUniswapV3Position.PositionInfo memory posInfo;
    IWUniswapV3Position wrapper;
    {
      // query position info from position id
      (, collateralTokenAddress, collateralTokenId, collateralAmount) = bank
        .getPositionInfo(_positionId);

      wrapper = IWUniswapV3Position(collateralTokenAddress);

      (
        ,
        ,
        ,
        ,
        ,
        ,
        ,
        ,
        feeGrowthInside0LastX128,
        feeGrowthInside1LastX128,
        ,

      ) = npm.positions(collateralTokenId);

      posInfo = wrapper.getPositionInfoFromTokenId(collateralTokenId);
    }
    IUniswapV3Pool pool = IUniswapV3Pool(
      factory.getPool(posInfo.token0, posInfo.token1, posInfo.fee)
    );
    (, int24 curTick, , , , , ) = pool.slot0();

    (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = pool
      .positions(
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
}
