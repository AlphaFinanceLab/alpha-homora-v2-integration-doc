// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./UtilsOP.sol";
import "../../contracts/op/uniswapv3/UniswapV3SpellIntegration.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3Factory.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3Router.sol";
import "../../../../interfaces/op/uniswapv3/IWUniswapV3Position.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3PositionManager.sol";
import "../../../../interfaces/op/uniswapv3/IUniswapV3Spell.sol";

import "forge-std/console2.sol";

contract UniswapV3SpellV3SpellIntegrationTest is UtilsOP {
  using SafeERC20 for IERC20;

  IBankOP bank = IBankOP(bankAddress);

  // TODO: change spell address you want
  IUniswapV3Spell spell =
    IUniswapV3Spell(0xBF956ECDbd08d9aeA6Ef0Cdd305d054859EBc130); // spell to interact with
  IUniswapV3Factory factory =
    IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984); // uniswap v3 factory
  IUniswapV3Router router =
    IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564); // uniswap v3 router
  IWUniswapV3Position wrapper =
    IWUniswapV3Position(0xAf8C59De82f10d21749952b3d44CcF6Ab97Ca0c7); // uniswap v3 wrapper
  IUniswapV3PositionManager npm =
    IUniswapV3PositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88); // uniswap v3 position manager

  // TODO: change token0 you want
  address token0 = WETH; // The first token of pool
  // TODO: change token1 you want
  address token1 = USDC; // The second token of pool

  uint24 fee = 500;

  UniswapV3SpellIntegration integration;
  address lp;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), "spell");

    // deploy integration contract
    integration = new UniswapV3SpellIntegration(bank, factory, npm);
    lp = factory.getPool(token0, token1, fee);

    prepareTokens(alice, token0, token1, address(integration));

    // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
    // NOTE: set whitelist contract must be executed from ALPHA governor
    setWhitelistContract(bank, alice, address(integration));

    // set credit limit that integration contract can be borrow with uncollateralized loan
    setCreditLimit(
      bank,
      address(integration),
      token0,
      type(uint256).max,
      alice
    );
    setCreditLimit(
      bank,
      address(integration),
      token1,
      type(uint256).max,
      alice
    );
  }

  function testAll() public {
    uint256 positionId = testOpenPosition();
    testIncreasePosition(positionId);
    testGetPendingRewards(positionId);
    testHarvestFee(positionId);
    testReducePosition(positionId);
    testClosePosition(positionId);
  }

  function testOpenPosition() internal returns (uint256 positionId) {
    // user info before
    uint256 userBalanceToken0_before = balanceOf(token0, alice);
    uint256 userBalanceToken1_before = balanceOf(token1, alice);

    // assume that user wants to open position by calling to integration contract
    // so integration contract will forward a request to HomoraBank further

    // call contract
    vm.startPrank(alice);
    positionId = integration.openPosition(
      address(spell),
      UniswapV3SpellIntegration.OpenPositionParams(
        token0,
        token1,
        fee,
        -206710,
        -198590,
        10**18,
        500 * 10**6,
        1 * 10**17,
        100 * 10**6,
        0,
        0,
        0,
        0,
        false,
        2**256 - 1
      )
    );
    vm.stopPrank();

    // user info after
    uint256 userBalanceToken0_after = balanceOf(token0, alice);
    uint256 userBalanceToken1_after = balanceOf(token1, alice);

    require(
      userBalanceToken0_before > userBalanceToken0_after,
      "incorrect user balance of token0"
    );
    require(
      userBalanceToken1_before > userBalanceToken1_after,
      "incorrect user balance of token1"
    );
  }

  function testIncreasePosition(uint256 positionId) internal {
    // user info before
    uint256 userBalanceToken0_before = balanceOf(token0, alice);
    uint256 userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice);
    integration.increasePosition(
      positionId,
      address(spell),
      UniswapV3SpellIntegration.AddLiquidityParams(
        1 * 10**IERC20Metadata(token0).decimals(),
        10 * 10**IERC20Metadata(token1).decimals(),
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        2**256 - 1
      )
    );
    vm.stopPrank();

    // user info after
    uint256 userBalanceToken0_after = balanceOf(token0, alice);
    uint256 userBalanceToken1_after = balanceOf(token1, alice);

    require(
      userBalanceToken0_before > userBalanceToken0_after,
      "incorrect user balance of token0"
    );
    require(
      userBalanceToken1_before > userBalanceToken1_after,
      "incorrect user balance of token1"
    );
  }

  function testReducePosition(uint256 positionId) internal {
    // get collateral information from position id
    (, , , uint256 collateralAmount) = bank.getPositionInfo(positionId);

    uint256 amtLPTake = collateralAmount / 20; // withdraw 5% of position

    // user info before
    uint256 userBalanceToken0_before = balanceOf(token0, alice);
    uint256 userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice);
    integration.reducePosition(
      address(spell),
      positionId,
      UniswapV3SpellIntegration.RemoveLiquidityParams(
        amtLPTake,
        0,
        0,
        0,
        0,
        2**256 - 1
      )
    );
    vm.stopPrank();

    // user info after
    uint256 userBalanceToken0_after = balanceOf(token0, alice);
    uint256 userBalanceToken1_after = balanceOf(token1, alice);

    require(
      userBalanceToken0_after > userBalanceToken0_before,
      "incorrect user balance of token0"
    );
    require(
      userBalanceToken1_after > userBalanceToken1_before,
      "incorrect user balance of token1"
    );
  }

  function testHarvestFee(uint256 positionId) internal {
    // swap tokens to add fee in the pool
    _swapTokens(
      bob,
      token0,
      token1,
      10 * 10**IERC20Metadata(token0).decimals()
    );
    _swapTokens(
      bob,
      token1,
      token0,
      10000 * 10**IERC20Metadata(token1).decimals()
    );

    // user info before
    uint256 userBalanceToken0_before = balanceOf(token0, alice);
    uint256 userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestFee(address(spell), positionId, false);
    vm.stopPrank();

    // user info after
    uint256 userBalanceToken0_after = balanceOf(token0, alice);
    uint256 userBalanceToken1_after = balanceOf(token1, alice);

    require(
      userBalanceToken0_after > userBalanceToken0_before,
      "incorrect user balance of token0"
    );
    require(
      userBalanceToken1_after > userBalanceToken1_before,
      "incorrect user balance of token1"
    );
  }

  function testReinvest(uint256 positionId) internal {
    // swap tokens to add fee in the pool
    _swapTokens(
      bob,
      token0,
      token1,
      10 * 10**IERC20Metadata(token0).decimals()
    );
    _swapTokens(
      bob,
      token1,
      token0,
      10000 * 10**IERC20Metadata(token1).decimals()
    );

    (, , uint256 collateralId, uint256 oldCollateralAmount) = bank
      .getPositionInfo(positionId);
    IWUniswapV3Position.PositionInfo memory posInfo = wrapper
      .getPositionInfoFromTokenId(collateralId);

    uint256 oldLiquidity = posInfo.liquidity;

    // call contract
    vm.startPrank(alice);
    integration.reinvest(
      address(spell),
      positionId,
      UniswapV3SpellIntegration.ReinvestParams(0, 0, false, 0, 0, 2**256 - 1)
    );
    vm.stopPrank();

    (, , , uint256 newCollateralAmount) = bank.getPositionInfo(positionId);
    posInfo = wrapper.getPositionInfoFromTokenId(collateralId);

    require(posInfo.liquidity > oldLiquidity, "incorrect liquidity info");
    require(
      oldCollateralAmount < newCollateralAmount,
      "incorrect collateral amount"
    );
  }

  function testClosePosition(uint256 positionId) internal {
    // user info before
    uint256 userBalanceToken0_before = balanceOf(token0, alice);
    uint256 userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice);
    integration.closePosition(
      address(spell),
      positionId,
      UniswapV3SpellIntegration.ClosePositionParams(0, 0, 2**256 - 1, false)
    );
    vm.stopPrank();

    // user info after
    uint256 userBalanceToken0_after = balanceOf(token0, alice);
    uint256 userBalanceToken1_after = balanceOf(token1, alice);

    require(
      userBalanceToken0_after > userBalanceToken0_before,
      "incorrect user balance of token0"
    );
    require(
      userBalanceToken1_after > userBalanceToken1_before,
      "incorrect user balance of token1"
    );
  }

  function testGetPendingRewards(uint256 positionId) internal {
    // increase block timestamp to calculate more rewards
    _swapTokens(
      bob,
      token0,
      token1,
      10 * 10**IERC20Metadata(token0).decimals()
    );
    _swapTokens(
      bob,
      token1,
      token0,
      10000 * 10**IERC20Metadata(token1).decimals()
    );

    // // call contract
    (uint256 fee0, uint256 fee1) = integration.getPendingFees(positionId);
    console2.log("pendingRewards fee0:", fee0);
    console2.log("pendingRewards fee1:", fee1);

    // user info before
    uint256 userBalanceToken0_before = balanceOf(token0, alice);
    uint256 userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestFee(address(spell), positionId, false);
    vm.stopPrank();

    // user info after
    uint256 userBalanceToken0_after = balanceOf(token0, alice);
    uint256 userBalanceToken1_after = balanceOf(token1, alice);

    console2.log(
      "claimed fee0: ",
      userBalanceToken0_after - userBalanceToken0_before
    );
    console2.log(
      "claimed fee1: ",
      userBalanceToken1_after - userBalanceToken1_before
    );

    require(userBalanceToken0_after - userBalanceToken0_before == fee0);
    require(userBalanceToken1_after - userBalanceToken1_before == fee1);
  }

  function _swapTokens(
    address caller,
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) internal {
    deal(tokenIn, caller, amountIn);
    require(IERC20(tokenIn).balanceOf(caller) >= amountIn);

    vm.startPrank(caller);
    if (IERC20(tokenIn).allowance(caller, address(router)) != 2**256 - 1) {
      IERC20(tokenIn).safeApprove(address(router), 2**256 - 1);
    }

    IUniswapV3Router.ExactInputSingleParams
      memory exactInputSingleParams = IUniswapV3Router.ExactInputSingleParams({
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: fee,
        recipient: caller,
        deadline: type(uint256).max,
        amountIn: amountIn,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });
    router.exactInputSingle(exactInputSingleParams);
    vm.stopPrank();
  }
}
