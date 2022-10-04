// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsETH.sol';
import '../../contracts/utils/uniswapv3/TickMath.sol';
import '../../contracts/eth/UniswapV3SpellIntegrationETH.sol';
import '../../interfaces/homorav2/IUniswapv3OptimalSwap.sol';
import '../../interfaces/homorav2/wrappers/IWUniswapV3Position.sol';
import '../../interfaces/homorav2/spells/IUniswapV3Spell.sol';
import '../../interfaces/uniswapv3/IUniswapV3Factory.sol';
import '../../interfaces/uniswapv3/IUniswapV3Router.sol';
import '../../interfaces/uniswapv3/IUniswapV3PositionManager.sol';

import 'forge-std/console2.sol';

contract UniswapV3SpellV3SpellIntegrationTestETH is UtilsETH {
  using SafeERC20 for IERC20;

  IBankETH bank = IBankETH(bankAddress);

  // TODO: change spell address you want
  IUniswapV3Spell spell = IUniswapV3Spell(0x0B8F60Be035cc5B1982ED2145c6BFC05F863ddc1); // spell to interact with
  IUniswapV3Factory factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984); // uniswap v3 factory
  IUniswapV3Router router = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564); // uniswap v3 router
  IWUniswapV3Position wrapper = IWUniswapV3Position(0x4fb70edDA7f67BdBE225df7C91483c45699293f5); // uniswap v3 wrapper
  IUniswapV3PositionManager npm =
    IUniswapV3PositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88); // uniswap v3 position manager
  IUniswapV3OptimalSwap optimalSwap =
    IUniswapV3OptimalSwap(0xdE58495Cf0763c0A918B7A9e22bfb5C2Aaf115f9); // uniswap v3 optimal swap

  // TODO: change token0, token1, fee you want
  address token0 = USDC; // The first token of pool
  address token1 = WETH; // The second token of pool
  uint24 fee = 500;

  /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
  int24 internal constant MIN_TICK = -887272;
  /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
  int24 internal constant MAX_TICK = -MIN_TICK;

  UniswapV3SpellIntegrationEth integration;
  address pool;
  uint24 tickSpacing;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');

    // deploy integration contract
    integration = new UniswapV3SpellIntegrationEth(bank, factory, npm);

    drainETH(address(integration));
    pool = factory.getPool(token0, token1, fee);
    require(pool != address(0), 'pool is zero address');
    tickSpacing = uint24(IUniswapV3Pool(pool).tickSpacing());

    prepareTokens(alice, token0, token1, address(integration));

    // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
    // NOTE: set whitelist contract must be executed from ALPHA governor
    setWhitelistContractWithTxOrigin(bank, alice, address(integration));

    // set credit limit that integration contract can be borrow with uncollateralized loan
    setCreditLimit(bank, address(integration), token0, type(uint).max, alice);
    setCreditLimit(bank, address(integration), token1, type(uint).max, alice);
  }

  function testAll() public {
    uint positionId = testOpenPosition();
    testIncreasePosition(positionId);
    testGetPendingRewards(positionId);
    testHarvestFee(positionId);
    testReducePosition(positionId);
    testClosePosition(positionId);

    testOpenPositionWithOptimalSwap();
  }

  function testOpenPosition() internal returns (uint positionId) {
    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // assume that user wants to open position by calling to integration contract
    // so integration contract will forward a request to HomoraBank further

    // call contract
    vm.startPrank(alice, alice);
    positionId = integration.openPosition(
      spell,
      IUniswapV3Spell.OpenPositionParams(
        token0,
        token1,
        fee,
        104540,
        304480,
        130 * 10**IERC20Metadata(token0).decimals(),
        10**IERC20Metadata(token1).decimals() / 10,
        (13 * 10**IERC20Metadata(token0).decimals()) / 100,
        10**IERC20Metadata(token1).decimals() / 1000,
        0,
        0,
        0,
        0,
        false,
        type(uint).max
      )
    );
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);

    require(userBalanceToken0_before > userBalanceToken0_after, 'incorrect user balance of token0');
    require(userBalanceToken1_before > userBalanceToken1_after, 'incorrect user balance of token1');
  }

  function testIncreasePosition(uint positionId) internal {
    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice, alice);
    integration.increasePosition(
      positionId,
      spell,
      IUniswapV3Spell.AddLiquidityParams(
        130 * 10**IERC20Metadata(token0).decimals(),
        10**IERC20Metadata(token1).decimals() / 10,
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        type(uint).max
      )
    );
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);

    require(userBalanceToken0_before > userBalanceToken0_after, 'incorrect user balance of token0');
    require(userBalanceToken1_before > userBalanceToken1_after, 'incorrect user balance of token1');
  }

  function testReducePosition(uint positionId) internal {
    // get collateral information from position id
    (, , , uint collateralAmount) = bank.getPositionInfo(positionId);

    uint amtLPTake = collateralAmount / 20; // withdraw 5% of position

    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice, alice);
    integration.reducePosition(
      positionId,
      spell,
      IUniswapV3Spell.RemoveLiquidityParams(amtLPTake, 0, 0, 0, 0, type(uint).max)
    );
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);

    require(userBalanceToken0_after > userBalanceToken0_before, 'incorrect user balance of token0');
    require(userBalanceToken1_after > userBalanceToken1_before, 'incorrect user balance of token1');
  }

  function testHarvestFee(uint positionId) internal {
    // swap tokens to add fee in the pool
    _swapTokens(bob, token0, token1, 13000 * 10**IERC20Metadata(token0).decimals());
    _swapTokens(bob, token1, token0, 10 * 10**IERC20Metadata(token1).decimals());

    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice, alice);
    integration.harvestFee(positionId, spell, false);
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);
    console2.log(userBalanceToken0_after, userBalanceToken0_before);

    require(userBalanceToken0_after > userBalanceToken0_before, 'incorrect user balance of token0');
    require(userBalanceToken1_after > userBalanceToken1_before, 'incorrect user balance of token1');
  }

  function testReinvest(uint positionId) internal {
    // swap tokens to add fee in the pool
    _swapTokens(bob, token0, token1, 13000 * 10**IERC20Metadata(token0).decimals());
    _swapTokens(bob, token1, token0, 10 * 10**IERC20Metadata(token1).decimals());

    (, , uint collateralId, uint oldCollateralAmount) = bank.getPositionInfo(positionId);
    IWUniswapV3Position.PositionInfo memory posInfo = wrapper.getPositionInfoFromTokenId(
      collateralId
    );

    uint oldLiquidity = posInfo.liquidity;

    // call contract
    vm.startPrank(alice, alice);
    integration.reinvest(
      positionId,
      spell,
      IUniswapV3Spell.ReinvestParams(0, 0, false, 0, 0, type(uint).max)
    );
    vm.stopPrank();

    (, , , uint newCollateralAmount) = bank.getPositionInfo(positionId);
    posInfo = wrapper.getPositionInfoFromTokenId(collateralId);

    require(posInfo.liquidity > oldLiquidity, 'incorrect liquidity info');
    require(oldCollateralAmount < newCollateralAmount, 'incorrect collateral amount');
  }

  function testClosePosition(uint positionId) internal {
    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice, alice);
    integration.closePosition(
      positionId,
      spell,
      IUniswapV3Spell.ClosePositionParams(0, 0, type(uint).max, false)
    );
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);

    require(userBalanceToken0_after > userBalanceToken0_before, 'incorrect user balance of token0');
    require(userBalanceToken1_after > userBalanceToken1_before, 'incorrect user balance of token1');
  }

  function testGetPendingRewards(uint positionId) internal {
    // swap tokens to generate fees for pool
    _swapTokens(bob, token0, token1, 13000 * 10**IERC20Metadata(token0).decimals());
    _swapTokens(bob, token1, token0, 10 * 10**IERC20Metadata(token1).decimals());

    // // call contract
    (uint fee0, uint fee1) = integration.getPendingFees(positionId);
    console2.log('pendingRewards fee0:', fee0);
    console2.log('pendingRewards fee1:', fee1);

    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice, alice);
    integration.harvestFee(positionId, spell, false);
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);

    console2.log('claimed fee0: ', userBalanceToken0_after - userBalanceToken0_before);
    console2.log('claimed fee1: ', userBalanceToken1_after - userBalanceToken1_before);

    require(userBalanceToken0_after - userBalanceToken0_before == fee0, '!fee0');
    require(userBalanceToken1_after - userBalanceToken1_before == fee1, '!fee1');
  }

  function testOpenPositionWithOptimalSwap() internal {
    uint multiplier0 = 100;
    uint multiplier1 = 100;
    (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
    int24 currentTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    uint absTick = currentTick < 0 ? uint(-int(currentTick)) : uint(int(currentTick));
    absTick -= absTick % tickSpacing;
    currentTick = currentTick < 0 ? -int24(int(absTick)) : int24(int(absTick));
    int24 tickLower = int24(currentTick - int24(int(multiplier0 * tickSpacing)));
    int24 tickUpper = int24(currentTick + int24(int(multiplier1 * tickSpacing)));
    uint amt0User = 10 * 10**IERC20Metadata(token0).decimals();
    uint amt1User = 10 * 10**IERC20Metadata(token1).decimals();
    uint amt0Borrow = amt0User / 10;
    uint amt1Borrow = amt1User / 10;
    (uint amtSwap, uint amtOut, bool isZeroForOne) = optimalSwap.getOptimalSwapAmt(
      IUniswapV3Pool(pool),
      amt0User + amt0Borrow,
      amt1User + amt1Borrow,
      tickLower,
      tickUpper
    );

    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice, alice);
    integration.openPosition(
      spell,
      IUniswapV3Spell.OpenPositionParams(
        token0,
        token1,
        fee,
        tickLower,
        tickUpper,
        amt0User,
        amt1User,
        amt0Borrow,
        amt1Borrow,
        0,
        0,
        amtSwap,
        amtOut,
        isZeroForOne,
        type(uint).max
      )
    );
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);

    require(userBalanceToken0_before > userBalanceToken0_after, 'incorrect user balance of token0');
    require(userBalanceToken1_before > userBalanceToken1_after, 'incorrect user balance of token1');
  }

  function _swapTokens(
    address caller,
    address tokenIn,
    address tokenOut,
    uint amountIn
  ) internal {
    deal(tokenIn, caller, amountIn);
    require(IERC20(tokenIn).balanceOf(caller) >= amountIn, '!amountIn');

    vm.startPrank(caller);
    if (IERC20(tokenIn).allowance(caller, address(router)) != type(uint).max) {
      IERC20(tokenIn).safeApprove(address(router), type(uint).max);
    }

    IUniswapV3Router.ExactInputSingleParams memory exactInputSingleParams = IUniswapV3Router
      .ExactInputSingleParams({
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: fee,
        recipient: caller,
        deadline: type(uint).max,
        amountIn: amountIn,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });
    router.exactInputSingle(exactInputSingleParams);
    vm.stopPrank();
  }
}
