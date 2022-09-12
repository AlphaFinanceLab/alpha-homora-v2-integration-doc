// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsETH.sol';
import '../../contracts/eth/uniswapv2/UniswapV2SpellV1Integration.sol';
import '../../interfaces/eth/uniswapv2/IUniswapV2Factory.sol';
import '../../interfaces/eth/uniswapv2/IUniswapV2SpellV1.sol';
import '../../interfaces/eth/uniswapv2/IWStakingRewards.sol';

import 'forge-std/console2.sol';

contract UniswapV2SpellV1Test is UtilsETH {
  using SafeERC20 for IERC20;

  IBankETH bank = IBankETH(bankAddress);

  // TODO: change spell address you want
  IUniswapV2SpellV1 spell = IUniswapV2SpellV1(0x00b1a4E7F217380a7C9e6c12F327AC4a1D9B6A14); // spell to interact with
  IUniswapV2Factory factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); // uniswapv2 factory

  // TODO: change tokenA, tokenB, poolID you want
  address tokenA = WETH; // The first token of pool
  address tokenB = DPI; // The second token of pool
  address wstaking = 0x011535FD795fD28c749363E080662D62fBB456a7; // WStaking address (INDEX)

  UniswapV2SpellV1Integration integration;
  address lp;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');

    // deploy integration contract
    integration = new UniswapV2SpellV1Integration(bank, factory);
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
    testGetPendingRewards(positionId);
    testHarvestRewards(positionId);
    testReducePosition(positionId);
  }

  function testOpenPosition() internal returns (uint positionId) {
    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    UniswapV2SpellV1Integration.AddLiquidityParams memory params = UniswapV2SpellV1Integration
      .AddLiquidityParams(
        tokenA,
        tokenB,
        100 * 10**IERC20Metadata(tokenA).decimals(),
        10**IERC20Metadata(tokenB).decimals(),
        100,
        50 * 10**IERC20Metadata(tokenA).decimals(),
        10**IERC20Metadata(tokenB).decimals() / 2,
        0,
        0,
        0,
        wstaking
      );

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);

    // assume that user wants to open position by calling to integration contract
    // so integration contract will forward a request to HomoraBank further

    // call contract
    vm.startPrank(alice);
    positionId = integration.openPositionWStaking(spell, params);
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

    IWStakingRewards wrapper = IWStakingRewards(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.reward());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    UniswapV2SpellV1Integration.AddLiquidityParams memory params = UniswapV2SpellV1Integration
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
        wstaking
      );

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.increasePositionWStaking(_positionId, spell, params);
    vm.stopPrank();

    // user info after
    uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    uint userBalanceLP_after = balanceOf(lp, alice);
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    require(userBalanceTokenA_before > userBalanceTokenA_after, 'incorrect user balance of tokenA');
    require(userBalanceTokenB_before > userBalanceTokenB_after, 'incorrect user balance of tokenB');
    require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
    // NOTE: no rewards returned since reward distribution from staking has been done
    require(
      userBalanceReward_after == userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testReducePosition(uint _positionId) internal {
    // increase block timestamp to calculate more rewards
    vm.warp(block.timestamp + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , uint collateralAmount) = bank.getPositionInfo(_positionId);

    IWStakingRewards wrapper = IWStakingRewards(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.reward());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    UniswapV2SpellV1Integration.RemoveLiquidityParams memory params = UniswapV2SpellV1Integration
      .RemoveLiquidityParams(
        tokenA,
        tokenB,
        collateralAmount,
        100,
        type(uint).max,
        type(uint).max,
        0,
        0,
        0,
        wstaking
      );

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.reducePositionWStaking(_positionId, spell, params);
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
    // NOTE: no rewards returned since reward distribution from staking has been done
    require(
      userBalanceReward_after == userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testHarvestRewards(uint _positionId) internal {
    // increase block timestamp to calculate more rewards
    vm.warp(block.timestamp + 10000);

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWStakingRewards wrapper = IWStakingRewards(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.reward());

    // user info before
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestRewardsWStaking(_positionId, spell, wstaking);
    vm.stopPrank();

    // user info after
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    // NOTE: no rewards returned since reward distribution from staking has been done
    require(
      userBalanceReward_after == userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testGetPendingRewards(uint _positionId) internal {
    // increase block timestamp to calculate more rewards
    vm.warp(block.timestamp + 10000);

    // call contract
    uint pendingRewards = integration.getPendingRewards(_positionId);
    require(pendingRewards == 0, 'pending rewards should be zero');

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWStakingRewards wrapper = IWStakingRewards(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.reward());

    // user info before
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestRewardsWStaking(_positionId, spell, wstaking);
    vm.stopPrank();

    // user info after
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    uint claimedRewards = userBalanceReward_after - userBalanceReward_before;
    require(pendingRewards == claimedRewards, 'unexpected reward amount');
  }
}
