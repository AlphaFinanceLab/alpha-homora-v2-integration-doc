// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsFTM.sol';
import '../../contracts/ftm/spiritswap/SpiritSwapSpellV1Integration.sol';
import '../../interfaces/ftm/IBankFTM.sol';
import '../../interfaces/ftm/spiritswap/ISpiritSwapFactory.sol';
import '../../interfaces/ftm/spiritswap/ISpiritSwapSpellV1.sol';
import '../../interfaces/ftm/spiritswap/IMasterChefSpirit.sol';
import '../../interfaces/ftm/spiritswap/IWMasterChefSpirit.sol';

import 'forge-std/console2.sol';

contract SpiritSwapSpellV1Test is UtilsFTM {
  using SafeERC20 for IERC20;

  IBankFTM bank = IBankFTM(bankAddress);

  // TODO: change spell address you want
  ISpiritSwapSpellV1 spell = ISpiritSwapSpellV1(0x928f13D14FBDD933d812FCF777D9e18397D425de); // spell to interact with
  ISpiritSwapFactory factory = ISpiritSwapFactory(0xEF45d134b73241eDa7703fa787148D9C9F4950b0); // trader joe factory

  // TODO: change tokenA, tokenB, poolId you want
  address tokenA = WFTM; // The first token of pool
  address tokenB = USDC; // The second token of pool
  uint poolId = 4; // Pool id of MasterchefBoo

  SpiritSwapSpellV1Integration integration;
  address lp;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');

    // deploy integration contract
    integration = new SpiritSwapSpellV1Integration(bank, factory);
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
    SpiritSwapSpellV1Integration.AddLiquidityParams memory params = SpiritSwapSpellV1Integration
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
    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefSpirit wrapper = IWMasterChefSpirit(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    SpiritSwapSpellV1Integration.AddLiquidityParams memory params = SpiritSwapSpellV1Integration
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
    // NOTE: no rewards returned since SpiritSwapV1 pools have been migrated to new version already
    require(
      userBalanceReward_after == userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testReducePosition(uint _positionId) internal {
    // get collateral information from position id
    (, address collateralTokenAddress, , uint collateralAmount) = bank.getPositionInfo(_positionId);

    IWMasterChefSpirit wrapper = IWMasterChefSpirit(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

    // for actual run, please put amtAMin, amtBMin (slippage), or else you get attacked.
    SpiritSwapSpellV1Integration.RemoveLiquidityParams memory params = SpiritSwapSpellV1Integration
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
    // NOTE: no rewards returned since SpiritSwapV1 pools have been migrated to new version already
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

    IWMasterChefSpirit wrapper = IWMasterChefSpirit(collateralTokenAddress);

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

    // NOTE: no rewards returned since SpiritSwapV1 pools have been migrated to new version already
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
    // NOTE: no rewards returned since SpiritSwapV1 pools have been migrated to new version already
    require(pendingRewards == 0, 'pending rewards should be zero');

    console2.log('pendingRewards:', pendingRewards);
  }
}
