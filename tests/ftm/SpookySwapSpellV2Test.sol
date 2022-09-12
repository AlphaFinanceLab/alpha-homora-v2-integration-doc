// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsFTM.sol';
import '../../contracts/ftm/spookyswap/SpookySwapSpellV2Integration.sol';
import '../../interfaces/ftm/IBankFTM.sol';
import '../../interfaces/ftm/spookyswap/ISpookySwapFactory.sol';
import '../../interfaces/ftm/spookyswap/ISpookySwapSpellV2.sol';
import '../../interfaces/ftm/spookyswap/IMasterChefBooV2.sol';
import '../../interfaces/ftm/spookyswap/IWMasterChefBooV2.sol';

import 'forge-std/console2.sol';

contract SpookySwapSpellV2Test is UtilsFTM {
  using SafeERC20 for IERC20;

  IBankFTM bank = IBankFTM(bankAddress);

  // TODO: change spell address you want
  ISpookySwapSpellV2 spell = ISpookySwapSpellV2(0x04A65eaae1C6005a6522f5fd886F53Fce9F8a895); // spell to interact with
  ISpookySwapFactory factory = ISpookySwapFactory(0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3); // trader joe factory

  // TODO: change tokenA, tokenB, poolId you want
  address tokenA = WFTM; // The first token of pool
  address tokenB = USDC; // The second token of pool
  uint poolId = 10; // Pool id of MasterchefBoo

  SpookySwapSpellV2Integration integration;
  address lp;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');

    // deploy integration contract
    integration = new SpookySwapSpellV2Integration(bank, factory);
    lp = factory.getPair(tokenA, tokenB);

    // prepare fund for user
    prepareFund(alice, tokenA, tokenB, lp, address(integration));

    // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
    // NOTE: set whitelist contract must be executed from ALPHA governor
    setWhitelistContract(bank, alice, address(integration));

    // set credit limit that integration contract can be borrow with uncollateralized loan
    setCreditLimit(bank, address(integration), tokenA, type(uint).max);
    setCreditLimit(bank, address(integration), tokenB, type(uint).max);
  }

  function testAll() public {
    uint positionId = testOpenPosition();
    testIncreasePosition(positionId);
    testGetPendingRewards(positionId);
    testHarvestRewards(positionId);
    testReducePosition(positionId);
  }

  function testOpenPosition() internal returns (uint positionId) {
    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    SpookySwapSpellV2Integration.AddLiquidityParams memory params = SpookySwapSpellV2Integration
      .AddLiquidityParams(
        tokenA,
        tokenB,
        10**IERC20Metadata(tokenA).decimals(),
        10**IERC20Metadata(tokenB).decimals(),
        100,
        10**IERC20Metadata(tokenA).decimals(),
        10**IERC20Metadata(tokenB).decimals(),
        0,
        0,
        0,
        poolId
      );

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
    vm.warp(block.timestamp + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    SpookySwapSpellV2Integration.AddLiquidityParams memory params = SpookySwapSpellV2Integration
      .AddLiquidityParams(
        tokenA,
        tokenB,
        10**IERC20Metadata(tokenA).decimals(),
        10**IERC20Metadata(tokenB).decimals(),
        100,
        10**IERC20Metadata(tokenA).decimals(),
        10**IERC20Metadata(tokenB).decimals(),
        0,
        0,
        0,
        poolId
      );

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
    vm.warp(block.timestamp + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , uint collateralAmount) = bank.getPositionInfo(_positionId);

    IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    SpookySwapSpellV2Integration.RemoveLiquidityParams memory params = SpookySwapSpellV2Integration
      .RemoveLiquidityParams(
        tokenA,
        tokenB,
        collateralAmount,
        100,
        type(uint).max,
        type(uint).max,
        0,
        0,
        0
      );

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
    vm.warp(block.timestamp + 10000);

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

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
    vm.warp(block.timestamp + 10000);

    // call contract
    uint pendingRewards = integration.getPendingRewards(_positionId);
    require(pendingRewards > 0, 'pending rewards should be more than 0');

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

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
