// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsETH.sol';
import '../../contracts/eth/curve/CurveSpellV1Integration.sol';

import 'forge-std/console2.sol';

contract CurveSpellV1Test is UtilsETH {
  using SafeERC20 for IERC20;

  IBankETH bank = IBankETH(bankAddress);
  address spell = 0x8b947D8448CFFb89EF07A6922b74fBAbac219795;
  address lp = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
  ICurveRegistry registry = ICurveRegistry(0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c);
  CurveSpellV1Integration integration;

  address[] tokens = [DAI, USDC, USDT];

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');
    vm.label(0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c, 'registry');
    vm.label(0xf1F32C8EEb06046d3cc3157B8F9f72B09D84ee5b, 'wgauge');

    // deploy integration contract
    integration = new CurveSpellV1Integration(bank, registry, CRV);

    // prepare fund for user
    prepareFundV2(alice, tokens, lp, address(integration));

    // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
    // NOTE: set whitelist contract must be executed from ALPHA governor
    setWhitelistContract(bank, alice, address(integration));

    // set credit limit that integration contract can be borrow with uncollateralized loan
    setCreditLimit(bank, address(integration), DAI, type(uint).max, alice);
    setCreditLimit(bank, address(integration), USDC, type(uint).max, alice);
    setCreditLimit(bank, address(integration), USDT, type(uint).max, alice);
  }

  function testAll() public {
    uint positionId = testOpenPosition();
    testIncreasePosition(positionId);
    testGetPendingRewards(positionId);
    testHarvestRewards(positionId);
    testReducePosition(positionId);
  }

  function testOpenPosition() internal returns (uint positionId) {
    CurveSpellV1Integration.AddLiquidity3Params memory params;
    params.lp = lp;
    params.amtLPUser = 100;
    params.amtLPBorrow = 0;
    params.minLPMint = 0;
    params.pid = 0;
    params.gid = 0;

    // user input
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsUser[i] = 1 * 10**IERC20Metadata(tokens[i]).decimals();
      params.amtsBorrow[i] = 1 * 10**IERC20Metadata(tokens[i]).decimals();
    }

    // user info before
    uint[] memory userBalanceTokens_before = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_before = balanceOf(lp, alice);

    // assume that user wants to open position by calling to integration contract
    // so integration contract will forward a request to HomoraBank further

    // call contract
    vm.startPrank(alice);
    positionId = integration.openPosition(address(spell), params);
    vm.stopPrank();

    // user info after
    uint[] memory userBalanceTokens_after = new uint[](tokens.length);
    for (uint i = 0; i < userBalanceTokens_after.length; i++) {
      userBalanceTokens_after[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_after = balanceOf(lp, alice);

    for (uint i = 0; i < tokens.length; i++) {
      require(
        userBalanceTokens_before[i] > userBalanceTokens_after[i],
        'incorrect user balance of token'
      );
    }
    require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
  }

  function testIncreasePosition(uint _positionId) public {
    // increase block number to calculate more rewards
    vm.warp(block.timestamp + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWLiquidityGauge wrapper = IWLiquidityGauge(collateralTokenAddress);

    CurveSpellV1Integration.AddLiquidity3Params memory params;
    params.lp = lp;
    params.amtLPUser = 100;
    params.amtLPBorrow = 0;
    params.minLPMint = 0;
    params.pid = 0;
    params.gid = 0;

    // find reward token address
    address rewardToken = address(wrapper.crv());

    for (uint i = 0; i < tokens.length; i++) {
      params.amtsUser[i] = 1 * 10**IERC20Metadata(tokens[i]).decimals();
    }

    for (uint i = 0; i < tokens.length; i++) {
      params.amtsBorrow[i] = params.amtsUser[i];
    }

    // user info before
    uint[] memory userBalanceTokens_before = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.increasePosition(_positionId, address(spell), params);
    vm.stopPrank();

    // user info after
    uint[] memory userBalanceTokens_after = new uint[](tokens.length);
    for (uint i = 0; i < userBalanceTokens_after.length; i++) {
      userBalanceTokens_after[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_after = balanceOf(lp, alice);
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    for (uint i = 0; i < tokens.length; i++) {
      require(
        userBalanceTokens_before[i] > userBalanceTokens_after[i],
        'incorrect user balance of token'
      );
    }
    require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
    require(
      userBalanceReward_after > userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testReducePosition(uint _positionId) public {
    // increase block number to calculate more rewards
    vm.warp(block.timestamp + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , uint collateralAmount) = bank.getPositionInfo(_positionId);

    IWLiquidityGauge wrapper = IWLiquidityGauge(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.crv());

    CurveSpellV1Integration.RemoveLiquidity3Params memory params;
    params.lp = lp;
    params.amtLPTake = collateralAmount; // withdraw 100% of position
    params.amtLPWithdraw = 100; // return only 100 LP to user
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsRepay[i] = type(uint).max; // repay 100% of tokenB
    }
    params.amtLPRepay = 0; // (always 0 since LP borrow is disallowed)
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsMin[i] = 0; // amount of token that user expects after withdrawal
    }

    // user info before
    uint[] memory userBalanceTokens_before = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.reducePosition(address(spell), _positionId, params);
    vm.stopPrank();

    // user info after
    uint[] memory userBalanceTokens_after = new uint[](tokens.length);
    for (uint i = 0; i < userBalanceTokens_after.length; i++) {
      userBalanceTokens_after[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_after = balanceOf(lp, alice);
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    for (uint i = 0; i < tokens.length; i++) {
      require(
        userBalanceTokens_after[i] > userBalanceTokens_before[i],
        'incorrect user balance of token'
      );
    }
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
    // increase block number to calculate more rewards
    vm.warp(block.timestamp + 10000);

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWLiquidityGauge wrapper = IWLiquidityGauge(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.crv());

    // user info before
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestRewards(address(spell), _positionId);
    vm.stopPrank();

    // user info after
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    require(
      userBalanceReward_after > userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testGetPendingRewards(uint _positionId) public {
    // increase block number to calculate more rewards
    vm.warp(block.timestamp + 10000);

    // call contract
    uint pendingRewards = integration.getPendingRewards(_positionId);
    require(pendingRewards > 0, 'pending rewards should be more than 0');

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWLiquidityGauge wrapper = IWLiquidityGauge(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.crv());

    // user info before
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.harvestRewards(address(spell), _positionId);
    vm.stopPrank();

    // user info after
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    uint claimedRewards = userBalanceReward_after - userBalanceReward_before;
    require(pendingRewards == claimedRewards, 'unexpected reward amount');
  }
}
