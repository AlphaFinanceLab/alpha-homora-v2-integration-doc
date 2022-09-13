// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsAVAX.sol';
import '../../contracts/avax/PangolinSpellV2IntegrationAvax.sol';
import '../../interfaces/homorav2/wrappers/IWMiniChefV2PNG.sol';
import '../../interfaces/homorav2/spells/IPangolinSpellV2.sol';
import '../../interfaces/pangolin/IMiniChefV2PNG.sol';
import '../../interfaces/pangolin/IPangolinFactory.sol';

import 'forge-std/console2.sol';

contract PangolinSpellV2Test is UtilsAVAX {
  using SafeERC20 for IERC20;

  IBankAVAX bank = IBankAVAX(bankAddress);

  // TODO: change spell address you want
  IPangolinSpellV2 spell = IPangolinSpellV2(0x966bbec3ac35452133B5c236b4139C07b1e2c9b1); // spell to interact with
  IPangolinFactory factory = IPangolinFactory(0xefa94DE7a4656D787667C749f7E1223D71E9FD88); // pangolin factory

  // TODO: change tokenA, tokenB, poolID you want
  address tokenA = WBTCe; // The first token of pool
  address tokenB = WAVAX; // The second token of pool
  uint poolId = 5; // Pool id of MinichefV2

  PangolinSpellV2IntegrationAvax integration;
  address lp;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');
    vm.label(0x1f806f7C8dED893fd3caE279191ad7Aa3798E928, 'minichefV2');
    vm.label(0xa67CF61b0b9BC39c6df04095A118e53BFb9303c7, 'wMinichefPNG');

    // deploy integration contract
    integration = new PangolinSpellV2IntegrationAvax(bank, factory);
    lp = factory.getPair(tokenA, tokenB);

    // prepare fund for user
    prepareFund(alice, tokenA, tokenB, lp, address(integration));

    // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
    // NOTE: set whitelist contract must be executed from ALPHA governor
    setWhitelistContract(bank, alice, address(integration));

    // set credit limit that integration contract can be borrow with uncollateralized loan
    setCreditLimit(bank, address(integration), tokenA, type(uint).max, alice);
    setCreditLimit(bank, address(integration), tokenB, type(uint).max, alice);
  }

  function testAll() public {
    uint positionId = testOpenPosition();
    testIncreasePosition(positionId);
    testHarvestRewards(positionId);
    testGetPendingRewards(positionId);
    testReducePosition(positionId);
  }

  function testOpenPosition() internal returns (uint positionId) {
    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    PangolinSpellV2IntegrationAvax.AddLiquidityParams memory params = PangolinSpellV2IntegrationAvax
      .AddLiquidityParams({
        tokenA: tokenA,
        tokenB: tokenB,
        amtAUser: 10**IERC20Metadata(tokenA).decimals(),
        amtBUser: 10**IERC20Metadata(tokenB).decimals(),
        amtLPUser: 100,
        amtABorrow: 10**IERC20Metadata(tokenA).decimals(),
        amtBBorrow: 10**IERC20Metadata(tokenB).decimals(),
        amtLPBorrow: 0,
        amtAMin: 0,
        amtBMin: 0,
        poolId: poolId
      });

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);

    // assume that user wants to open position by calling to integration contract
    // so integration contract will forward a request to HomoraBank further

    // call contract
    vm.startPrank(alice);
    positionId = integration.openPosition(spell, params);
    vm.stopPrank();

    // user info after
    uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    uint userBalanceLP_after = balanceOf(lp, alice);

    require(userBalanceTokenA_before > userBalanceTokenA_after, 'incorrect user balance of tokenA');
    require(userBalanceTokenB_before > userBalanceTokenB_after, 'incorrect user balance of tokenB');
    require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
  }

  function testIncreasePosition(uint _positionId) internal {
    // increase block timestamp to calculate more rewards
    vm.warp(block.timestamp + 1000);

    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.png());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    PangolinSpellV2IntegrationAvax.AddLiquidityParams memory params = PangolinSpellV2IntegrationAvax
      .AddLiquidityParams({
        tokenA: tokenA,
        tokenB: tokenB,
        amtAUser: 10**IERC20Metadata(tokenA).decimals(),
        amtBUser: 10**IERC20Metadata(tokenB).decimals(),
        amtLPUser: 100,
        amtABorrow: 10**IERC20Metadata(tokenA).decimals(),
        amtBBorrow: 10**IERC20Metadata(tokenB).decimals(),
        amtLPBorrow: 0,
        amtAMin: 0,
        amtBMin: 0,
        poolId: poolId
      });

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.increasePosition(_positionId, spell, params);
    vm.stopPrank();

    // user info after
    uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    uint userBalanceLP_after = balanceOf(lp, alice);
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    require(userBalanceTokenA_before > userBalanceTokenA_after, 'incorrect user balance of tokenA');
    require(userBalanceTokenB_before > userBalanceTokenB_after, 'incorrect user balance of tokenB');
    require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
    require(
      userBalanceReward_after > userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testReducePosition(uint _positionId) internal {
    // increase block timestamp to calculate more rewards
    vm.warp(block.timestamp + 1000);

    // get collateral information from position id
    (, address collateralTokenAddress, , uint collateralAmount) = bank.getPositionInfo(_positionId);

    IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.png());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    // identify type(uint).max if to amtRepay if you want to fully repay the accrued debt.
    PangolinSpellV2IntegrationAvax.RemoveLiquidityParams
      memory params = PangolinSpellV2IntegrationAvax.RemoveLiquidityParams({
        tokenA: tokenA,
        tokenB: tokenB,
        amtLPTake: collateralAmount,
        amtLPWithdraw: 100,
        amtARepay: type(uint).max,
        amtBRepay: type(uint).max,
        amtLPRepay: 0,
        amtAMin: 0,
        amtBMin: 0
      });

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.reducePosition(_positionId, spell, params);
    vm.stopPrank();

    // user info after
    uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    uint userBalanceLP_after = balanceOf(lp, alice);
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    require(userBalanceTokenA_after > userBalanceTokenA_before, 'incorrect user balance of tokenA');
    require(userBalanceTokenB_after > userBalanceTokenB_before, 'incorrect user balance of tokenB');
    require(
      userBalanceLP_after - userBalanceLP_before == params.amtLPWithdraw,
      'incorrect user balance of LP'
    );
    require(
      userBalanceReward_after > userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testHarvestRewards(uint _positionId) internal {
    // increase block timestamp to calculate more rewards
    vm.warp(block.timestamp + 1000);

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.png());

    // user info before
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestRewards(_positionId, spell);
    vm.stopPrank();

    // user info after
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    require(
      userBalanceReward_after > userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testGetPendingRewards(uint _positionId) internal {
    // increase block timestamp to calculate more rewards
    vm.warp(block.timestamp + 1000);

    // assume someone interacts Chef -> makes pending reward updated
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);
    IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);
    IMiniChefV2PNG chef = IMiniChefV2PNG(wrapper.chef());
    chef.updatePool(poolId);

    // call contract
    uint pendingRewards = integration.getPendingRewards(_positionId);
    require(pendingRewards > 0, 'pending rewards should be more than 0');

    // find reward token address
    address rewardToken = address(wrapper.png());

    // user info before
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestRewards(_positionId, spell);
    vm.stopPrank();

    // user info after
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    uint claimedRewards = userBalanceReward_after - userBalanceReward_before;

    console2.log('pendingRewards:', pendingRewards);
    console2.log('claimedRewards:', claimedRewards);
    require(pendingRewards == claimedRewards, 'unexpected reward amount');
  }
}
