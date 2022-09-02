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
  IUniswapV3PositionManager npm;

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

  uint256 constant X128UINT = 2**128;

  struct OpenPositionParams {
    address token0; // token0 of the pool.
    address token1; // token1 of the pool.
    uint24 fee; // pool fee.
    int24 tickLower; // tickLower
    int24 tickUpper; // tickUpper
    uint256 amt0User; // token0 amount that user provides.
    uint256 amt1User; // token1 amount that user provides.
    uint256 amt0Borrow; // token0 amount that user borrows.
    uint256 amt1Borrow; // token1 amount that user borrows.
    uint256 amt0Min; // minimum amount of token0 being used to provide liquidity.
    uint256 amt1Min; // minimum amount of token1 being used to provide liquidity.
    uint256 amtInOptimalSwap; // amount of tokens being used in swap for optimal deposit.
    uint256 amtOutMinOptimalSwap; // expected amount out for optimal deposit.
    bool isZeroForOneSwap; // do we swap token0 to token1 for optimal deposit.
    uint256 deadline; // deadline for increaseLiquidity and swap.
  }

  struct AddLiquidityParams {
    uint256 amt0User; // token0 amount that user provides.
    uint256 amt1User; // token1 amount that user provides.
    uint256 amt0Borrow; // token0 amount that user borrows.
    uint256 amt1Borrow; // token1 amount that user borrows.
    uint256 amt0Min; // minimum amount of token0 being used to provide liquidity.
    uint256 amt1Min; // minimum amount of token1 being used to provide liquidity.
    uint256 amtInOptimalSwap; // amount of tokens being used in swap for optimal deposit.
    uint256 amtOutMinOptimalSwap; // expected amount out for optimal deposit.
    bool isZeroForOneSwap; // do we swap token0 to token1 for optimal deposit.
    uint256 deadline; // deadline for increaseLiquidity and swap.
  }

  struct RemoveLiquidityParams {
    uint256 amtLiquidityTake; // amount of liquidity being removed.
    uint256 amt0Repay; // repay amount of token0.
    uint256 amt1Repay; // repay amount of token1.
    uint256 amt0Min; // minimum amount of token0 gain after remove liquidity and repay debt.
    uint256 amt1Min; // minimum amount of token1 gain after remove liquidity and repay debt.
    uint256 deadline; // deadline for decreaseLiquidity.
  }

  struct ClosePositionParams {
    uint256 amt0Min; // minimum amount of token0 gain after remove liquidity and repay debt.
    uint256 amt1Min; // minimum amount of token1 gain after remove liquidity and repay debt.
    uint256 deadline; // deadline for decreaseLiquidity.
    bool convertWETH; // deadline for decreaseLiquidity.
  }

  struct ReinvestParams {
    uint256 amtInOptimalSwap; // amount of tokens being used in swap for optimal deposit.
    uint256 amtOutMinOptimalSwap; // expected amount out for optimal deposit.
    bool isZeroForOneSwap; // do we swap token0 to token1 for optimal deposit.
    uint256 amt0Min; // minimum amount of token0 being used to provide liquidity.
    uint256 amt1Min; // minimum amount of token1 being used to provide liquidity.
    uint256 deadline; // deadline for increaseLiquidity.
  }

  constructor(
    IBankOP _bank,
    IUniswapV3Factory _factory,
    IUniswapV3PositionManager _npm
  ) {
    bank = _bank;
    factory = _factory;
    npm = _npm;
  }

  function openPosition(address spell, OpenPositionParams memory params)
    external
    returns (uint256 positionId)
  {
    // approve tokens
    ensureApprove(params.token0, address(bank));
    ensureApprove(params.token1, address(bank));

    // transfer tokens from user
    IERC20(params.token0).safeTransferFrom(
      msg.sender,
      address(this),
      params.amt0User
    );
    IERC20(params.token1).safeTransferFrom(
      msg.sender,
      address(this),
      params.amt1User
    );

    positionId = bank.execute(
      0, // (0 is reserved for opening new position)
      spell,
      abi.encodeWithSelector(
        openPositionSelector,
        IUniswapV3Spell.OpenPositionParams(
          params.token0,
          params.token1,
          params.fee,
          params.tickLower,
          params.tickUpper,
          params.amt0User,
          params.amt1User,
          params.amt0Borrow,
          params.amt1Borrow,
          params.amt0Min,
          params.amt1Min,
          params.amtInOptimalSwap,
          params.amtOutMinOptimalSwap,
          params.isZeroForOneSwap,
          params.deadline
        )
      )
    );

    doRefundETH();
    doRefund(params.token0);
    doRefund(params.token1);
  }

  function increasePosition(
    uint256 positionId,
    address spell,
    AddLiquidityParams memory params
  ) external {
    (, address collateralTokenAddress, uint256 collateralTokenId, ) = bank
      .getPositionInfo(positionId);
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
      params.amt0User
    );
    IERC20(posInfo.token1).safeTransferFrom(
      msg.sender,
      address(this),
      params.amt1User
    );
    bank.execute(
      positionId,
      spell,
      abi.encodeWithSelector(
        addLiquiditySelector,
        IUniswapV3Spell.AddLiquidityParams(
          params.amt0User,
          params.amt1User,
          params.amt0Borrow,
          params.amt1Borrow,
          params.amt0Min,
          params.amt1Min,
          params.amtInOptimalSwap,
          params.amtOutMinOptimalSwap,
          params.isZeroForOneSwap,
          params.deadline
        )
      )
    );

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function reducePosition(
    address spell,
    uint256 positionId,
    RemoveLiquidityParams memory params
  ) external {
    (, address collateralTokenAddress, uint256 collateralTokenId, ) = bank
      .getPositionInfo(positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralTokenId);

    bank.execute(
      positionId,
      spell,
      abi.encodeWithSelector(
        removeLiquiditySelector,
        IUniswapV3Spell.RemoveLiquidityParams(
          params.amtLiquidityTake,
          params.amt0Repay,
          params.amt1Repay,
          params.amt0Min,
          params.amt1Min,
          params.deadline
        )
      )
    );

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function harvestFee(
    address spell,
    uint256 positionId,
    bool convertWETH
  ) external {
    bank.execute(
      positionId,
      spell,
      abi.encodeWithSelector(harvestFeeSelector, convertWETH)
    );

    // query position info from position id
    (, address collateralTokenAddress, uint256 collateralTokenId, ) = bank
      .getPositionInfo(positionId);

    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);
    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralTokenId);

    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function closePosition(
    address spell,
    uint256 positionId,
    ClosePositionParams memory params
  ) external {
    (, address collateralTokenAddress, uint256 collateralId, ) = bank
      .getPositionInfo(positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralId);

    bank.execute(
      positionId,
      spell,
      abi.encodeWithSelector(
        closePositionSelector,
        IUniswapV3Spell.ClosePositionParams(
          params.amt0Min,
          params.amt1Min,
          params.deadline,
          params.convertWETH
        )
      )
    );
    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  function reinvest(
    address spell,
    uint256 positionId,
    ReinvestParams memory params
  ) external {
    (, address collateralTokenAddress, uint256 collateralId, ) = bank
      .getPositionInfo(positionId);
    IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralId);

    bank.execute(
      positionId,
      spell,
      abi.encodeWithSelector(
        reinvestSelector,
        IUniswapV3Spell.ReinvestParams(
          params.amtInOptimalSwap,
          params.amtOutMinOptimalSwap,
          params.isZeroForOneSwap,
          params.amt0Min,
          params.amt1Min,
          params.deadline
        )
      )
    );

    doRefundETH();
    doRefund(posInfo.token0);
    doRefund(posInfo.token1);
  }

  struct FeeGrowth {
    uint256 feeGrowthBelow0;
    uint256 feeGrowthBelow1;
    uint256 feeGrowthAbove0;
    uint256 feeGrowthAbove1;
  }

  // ref: from arrakis finance
  function _computeFeesEarned(
    IUniswapV3Pool pool,
    bool isZero,
    uint256 feeGrowthInsideLast,
    int24 tick,
    int24 lowerTick,
    int24 upperTick,
    uint128 liquidity
  ) private view returns (uint256 fee) {
    uint256 feeGrowthOutsideLower;
    uint256 feeGrowthOutsideUpper;
    uint256 feeGrowthGlobal;
    if (isZero) {
      feeGrowthGlobal = pool.feeGrowthGlobal0X128();
      (, , feeGrowthOutsideLower, , , , , ) = pool.ticks(lowerTick);
      (, , feeGrowthOutsideUpper, , , , , ) = pool.ticks(upperTick);
    } else {
      feeGrowthGlobal = pool.feeGrowthGlobal1X128();
      (, , , feeGrowthOutsideLower, , , , ) = pool.ticks(lowerTick);
      (, , , feeGrowthOutsideUpper, , , , ) = pool.ticks(upperTick);
    }

    unchecked {
      // calculate fee growth below
      uint256 feeGrowthBelow;
      if (tick >= lowerTick) {
        feeGrowthBelow = feeGrowthOutsideLower;
      } else {
        feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
      }

      // calculate fee growth above
      uint256 feeGrowthAbove;
      if (tick < upperTick) {
        feeGrowthAbove = feeGrowthOutsideUpper;
      } else {
        feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
      }

      uint256 feeGrowthInside = feeGrowthGlobal -
        feeGrowthBelow -
        feeGrowthAbove;
      fee = (liquidity * (feeGrowthInside - feeGrowthInsideLast)) / 2**128;
    }
  }

  function _getPositionID(
    address owner,
    int24 lowerTick,
    int24 upperTick
  ) internal view returns (bytes32 positionId) {
    return keccak256(abi.encodePacked(owner, lowerTick, upperTick));
  }

  function getPendingFees(uint256 positionId)
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
        .getPositionInfo(positionId);

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
