// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import './UtilsETH.sol';
import '../../contracts/eth/curve/CurveSpellV1Integration.sol';

contract CurveSpellV1Test is UtilsETH {
  using SafeERC20 for IERC20;

  IBankETH bank = IBankETH(bankAddress);
  address spell = 0x8b947D8448CFFb89EF07A6922b74fBAbac219795;
  address lp = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
  ICurveRegistry registry = ICurveRegistry(0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c);
  CurveSpellV1Integration integration;

  function setUp() public override {
    super.setUp();

    vm.label(address(spell), 'spell');
    vm.label(0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c, 'registry');
    vm.label(0xf1F32C8EEb06046d3cc3157B8F9f72B09D84ee5b, 'wgauge');

    // deploy integration contract
    integration = new CurveSpellV1Integration(bank, registry, CRV);

    // prepare fund for user
    address[] memory tokens = new address[](3);
    tokens[0] = DAI;
    tokens[1] = USDC;
    tokens[2] = USDT;
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
    // testIncreasePosition(positionId);
    // testHarvestRewards(positionId);
    // testGetPendingRewards(positionId);
    // testReducePosition(positionId);
  }

  function testOpenPosition() public returns (uint positionId) {
    CurveSpellV1Integration.AddLiquidityParams memory params;
    params.amtsUser = new uint[](3);
    params.amtLPUser = 1;
    params.amtsBorrow = new uint[](3);
    params.amtLPBorrow = 0;
    params.minLPMint = 0;
    params.pid = 0;
    params.gid = 0;

    // user info before
    // uint userBalanceTokenA_before = balanceOf(tokenA, alice);
    // uint userBalanceTokenB_before = balanceOf(tokenB, alice);
    // uint userBalanceLP_before = balanceOf(lp, alice);

    // assume that user wants to open position by calling to integration contract
    // so integration contract will forward a request to HomoraBank further

    // call contract
    vm.startPrank(alice);
    positionId = integration.openPosition(address(spell), params);
    vm.stopPrank();

    // user info after
    // uint userBalanceTokenA_after = balanceOf(tokenA, alice);
    // uint userBalanceTokenB_after = balanceOf(tokenB, alice);
    // uint userBalanceLP_after = balanceOf(lp, alice);

    // require(userBalanceTokenA_before > userBalanceTokenA_after, 'incorrect user balance of tokenA');
    // require(userBalanceTokenB_before > userBalanceTokenB_after, 'incorrect user balance of tokenB');
    // require(userBalanceLP_before > userBalanceLP_after, 'incorrect user balance of lp');
  }
}
