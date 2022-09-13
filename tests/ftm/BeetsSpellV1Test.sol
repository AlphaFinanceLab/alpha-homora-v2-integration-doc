// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsFTM.sol';
import '../../contracts/ftm/BeetsSpellV1IntegrationFtm.sol';
import '../../interfaces/homorav2/banks/IBankFTM.sol';
import '../../interfaces/beets/IBeetsPool.sol';
import '../../interfaces/beets/IBeetsVault.sol';
import '../../interfaces/homorav2/spells/IBeetsSpellV1.sol';
import '../../interfaces/homorav2/wrappers/IWMasterChefBeetsWorker.sol';

import 'forge-std/console2.sol';

contract BeetsSpellV1Test is UtilsFTM {
  using SafeERC20 for IERC20;

  IBankFTM bank = IBankFTM(bankAddress);

  // TODO: change spell address, vault, poolId, lp token you want
  IBeetsSpellV1 spell = IBeetsSpellV1(0xEeb9b7C60749fEC168ABE7382981428D6ac00C2F); // spell to interact with
  IBeetsVault vault = IBeetsVault(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce); // beets vault
  uint chefPoolId = 17; // Pool id of Beets MasterChef
  address lp = 0xf3A602d30dcB723A74a0198313a7551FEacA7DAc;

  BeetsSpellV1IntegrationFtm integration;
  address[] tokens;
  bytes32 vaultPoolId; // Pool id of Beets vault

  function setUp() public override {
    super.setUp();

    // deploy integration contract
    integration = new BeetsSpellV1IntegrationFtm(bank, vault);

    vm.label(address(spell), 'spell');
    vm.label(address(lp), 'lp');
    vm.label(address(integration), 'integration');

    IBeetsPool pool = IBeetsPool(lp);
    vaultPoolId = pool.getPoolId();
    (tokens, , ) = vault.getPoolTokens(vaultPoolId);

    // prepare fund for user
    prepareFundV2(alice, tokens, lp, address(integration));

    // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
    // NOTE: set whitelist contract must be executed from ALPHA governor
    setWhitelistContract(bank, alice, address(integration));

    // set credit limit that integration contract can be borrow with uncollateralized loan
    for (uint i = 0; i < tokens.length; i++) {
      setCreditLimit(bank, address(integration), tokens[i], type(uint).max);
    }
  }

  function testAll() public {
    uint positionId = testOpenPosition();
    testIncreasePosition(positionId);
    testGetPendingRewards(positionId);
    testHarvestRewards(positionId);
    testReducePosition(positionId);
  }

  function testOpenPosition() internal returns (uint positionId) {
    BeetsSpellV1IntegrationFtm.AddLiquidityParams memory params;
    params.vaultPoolId = vaultPoolId;
    params.amtsUser = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsUser[i] = (10 * 10**IERC20Metadata(tokens[i]).decimals());
    }
    params.amtsBorrow = new uint[](tokens.length);
    params.amtLPUser = 100;
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsBorrow[i] = params.amtsUser[i];
    }
    params.amtLPBorrow = 0;
    params.minLPMint = 0; // for actual run, please put minLPMint (slippage), or else you get attacked.
    params.chefPoolId = chefPoolId;

    // user info before
    uint[] memory userBalanceTokens_before = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_before = balanceOf(lp, alice);

    // call contract
    vm.startPrank(alice);
    positionId = integration.openPosition(spell, params);
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

  function testIncreasePosition(uint _positionId) internal {
    // increase block number to calculate more rewards
    vm.roll(block.number + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

    BeetsSpellV1IntegrationFtm.AddLiquidityParams memory params;
    params.vaultPoolId = vaultPoolId;
    params.amtsUser = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsUser[i] = (10 * 10**IERC20Metadata(tokens[i]).decimals());
    }
    params.amtsBorrow = new uint[](tokens.length);
    params.amtLPUser = 100;
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsBorrow[i] = params.amtsUser[i];
    }
    params.amtLPBorrow = 0;
    params.minLPMint = 0; // for actual run, please put minLPMint (slippage), or else you get attacked.
    params.chefPoolId = chefPoolId;

    // user info before
    uint[] memory userBalanceTokens_before = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
    }
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.increasePosition(_positionId, spell, params);
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

  function testReducePosition(uint _positionId) internal {
    // increase block number to calculate more rewards
    vm.roll(block.number + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , uint collateralAmount) = bank.getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.rewardToken());

    BeetsSpellV1IntegrationFtm.RemoveLiquidityParams memory params;
    params.vaultPoolId = vaultPoolId;
    params.amtLPTake = collateralAmount; // withdraw 100% of position
    params.amtLPWithdraw = 100; // return only 100 LP to user

    params.amtsRepay = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsRepay[i] = type(uint).max; // repay 100% of tokenB
    }
    params.amtLPRepay = 0; // (always 0 since LP borrow is disallowed)

    // for actual run, please put amtsMin[i] (slippage), or else you get attacked.
    params.amtsMin = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
      params.amtsMin[i] = 0;
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
    integration.reducePosition(_positionId, spell, params);
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
    vm.roll(block.number + 10000);

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);

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
    // increase block number to calculate more rewards
    vm.roll(block.number + 10000);

    // call contract
    uint pendingRewards = integration.getPendingRewards(_positionId);
    require(pendingRewards > 0, 'pending rewards should be more than 0');

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);

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
