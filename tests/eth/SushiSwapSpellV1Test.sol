// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsETH.sol';
import '../../contracts/eth/sushiswap/SushiswapSpellV1Integration.sol';
import '../../../../interfaces/eth/sushiswap/ISushiswapFactory.sol';
import '../../../../interfaces/eth/sushiswap/ISushiswapSpellV1.sol';
import '../../../../interfaces/eth/sushiswap/IWMasterChef.sol';

import 'forge-std/console2.sol';

contract SushiswapSpellV1Test is UtilsETH {
  using SafeERC20 for IERC20;

  IBankETH bank = IBankETH(bankAddress);

  // TODO: change spell address you want
  ISushiswapSpellV1 spell = ISushiswapSpellV1(0xDc9c7A2Bae15dD89271ae5701a6f4DB147BAa44C); // spell to interact with
  ISushiswapFactory factory = ISushiswapFactory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac); // sushiswap factory

  // TODO: change tokenA you want
  address tokenA = WETH; // The first token of pool
  // TODO: change tokenB you want
  address tokenB = DAI; // The second token of pool
  // TODO: change pool id you want
  uint pid = 2; // Pool id of MasterChef

  SushiswapSpellV1Integration integration;
  address lp;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');

    // deploy integration contract
    integration = new SushiswapSpellV1Integration(bank, factory);
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

  function testOpenPosition() public returns (uint positionId) {
    uint amtAUser = 100 * 10**IERC20Metadata(tokenA).decimals();
    uint amtBUser = (1 * 10**IERC20Metadata(tokenB).decimals()) / 1000;
    uint amtLPUser = 100;
    uint amtABorrow = amtAUser;
    uint amtBBorrow = amtBUser;
    uint amtLPBorrow = 0;
    uint amtAMin = 0;
    uint amtBMin = 0;

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);

    // assume that user wants to open position by calling to integration contract
    // so integration contract will forward a request to HomoraBank further

    // call contract
    vm.startPrank(alice);
    positionId = integration.openPosition(
      address(spell),
      SushiswapSpellV1Integration.AddLiquidityParams(
        tokenA,
        tokenB,
        amtAUser,
        amtBUser,
        amtLPUser,
        amtABorrow,
        amtBBorrow,
        amtLPBorrow,
        amtAMin,
        amtBMin,
        pid
      )
    );
    vm.stopPrank();

    // user info after
    uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    uint userBalanceLP_after = balanceOf(lp, alice);

    require(userBalanceTokenA_before > userBalanceTokenA_after, 'incorrect user balance of tokenA');
    require(userBalanceTokenB_before > userBalanceTokenB_after, 'incorrect user balance of tokenB');
    require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
  }

  function testIncreasePosition(uint _positionId) public {
    // increase block number to calculate more rewards
    vm.roll(block.number + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.sushi());

    uint amtAUser = 1 * 10**IERC20Metadata(tokenA).decimals();
    uint amtBUser = 1 * 10**IERC20Metadata(tokenB).decimals();
    uint amtLPUser = 100;
    uint amtABorrow = amtAUser;
    uint amtBBorrow = amtBUser;
    uint amtLPBorrow = 0;
    uint amtAMin = 0;
    uint amtBMin = 0;

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.increasePosition(
      _positionId,
      address(spell),
      SushiswapSpellV1Integration.AddLiquidityParams(
        tokenA,
        tokenB,
        amtAUser,
        amtBUser,
        amtLPUser,
        amtABorrow,
        amtBBorrow,
        amtLPBorrow,
        amtAMin,
        amtBMin,
        pid
      )
    );
    vm.stopPrank();

    // user info after
    uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    uint userBalanceLP_after = balanceOf(lp, alice);
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    console2.log('userBalanceReward_before:', userBalanceReward_before);
    console2.log('userBalanceReward_after:', userBalanceReward_after);

    require(userBalanceTokenA_before > userBalanceTokenA_after, 'incorrect user balance of tokenA');
    require(userBalanceTokenB_before > userBalanceTokenB_after, 'incorrect user balance of tokenB');
    require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
    require(
      userBalanceReward_after > userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testReducePosition(uint _positionId) public {
    // increase block number to calculate more rewards
    vm.roll(block.number + 10000);

    // get collateral information from position id
    (, address collateralTokenAddress, , uint collateralAmount) = bank.getPositionInfo(_positionId);

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.sushi());

    uint amtLPTake = collateralAmount; // withdraw 100% of position
    uint amtLPWithdraw = 100; // return only 100 LP to user
    uint amtARepay = type(uint).max; // repay 100% of tokenA
    uint amtBRepay = type(uint).max; // repay 100% of tokenB
    uint amtLPRepay = 0; // (always 0 since LP borrow is disallowed)
    uint amtAMin = 0; // amount of tokenA that user expects after withdrawal
    uint amtBMin = 0; // amount of tokenB that user expects after withdrawal

    // user info before
    uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    uint userBalanceLP_before = balanceOf(lp, alice);
    uint userBalanceReward_before = balanceOf(rewardToken, alice);

    // call contract
    vm.startPrank(alice);
    integration.reducePosition(
      address(spell),
      _positionId,
      SushiswapSpellV1Integration.RemoveLiquidityParams(
        tokenA,
        tokenB,
        amtLPTake,
        amtLPWithdraw,
        amtARepay,
        amtBRepay,
        amtLPRepay,
        amtAMin,
        amtBMin
      )
    );
    vm.stopPrank();

    // user info after
    uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    uint userBalanceLP_after = balanceOf(lp, alice);
    uint userBalanceReward_after = balanceOf(rewardToken, alice);

    require(userBalanceTokenA_after > userBalanceTokenA_before, 'incorrect user balance of tokenA');
    require(userBalanceTokenB_after > userBalanceTokenB_before, 'incorrect user balance of tokenB');
    require(
      userBalanceLP_after - userBalanceLP_before == amtLPWithdraw,
      'incorrect user balance of LP'
    );
    require(
      userBalanceReward_after > userBalanceReward_before,
      'incorrect user balance of reward token'
    );
  }

  function testHarvestRewards(uint _positionId) public {
    // increase block number to calculate more rewards
    vm.roll(block.number + 10000);

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.sushi());

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
    vm.roll(block.number + 10000);

    // call contract
    uint pendingRewards = integration.getPendingRewards(_positionId);
    require(pendingRewards > 0, 'pending rewards should be more than 0');

    // query position info from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);

    // find reward token address
    address rewardToken = address(wrapper.sushi());

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
