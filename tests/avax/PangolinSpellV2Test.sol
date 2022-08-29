// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../contracts/avax/SetupBankAvax.sol";
import "../../contracts/avax/pool/pangolin/PangolinSpellV2Integration.sol";
import "../../../../interfaces/avax/pangolin/IPangolinSpellV2.sol";

import "forge-std/console2.sol";

contract PangolinSpellV2Test is PangolinSpellV2Integration {
    using SafeERC20 for IERC20;

    // TODO: change spell address you want
    IPangolinSpellV2 spell =
        IPangolinSpellV2(0x966bbec3ac35452133B5c236b4139C07b1e2c9b1); // spell to interact with

    // TODO: change tokenA you want
    address tokenA = USDCe; // The first token of pool
    // TODO: change tokenB you want
    address tokenB = WAVAX; // The second token of pool
    // TODO: change pool id you want
    uint256 pid = 7; // Pool id of MinichefV2

    function setUp() public override {
        super.setUp();

        vm.label(address(spell), "spell");

        // prepare fund for user
        prepareFund();

        // set whitelist that this contract can call HomoraBank, otherwise tx will fail
        // NOTE: set whitelist contract must be executed from ALPHA governor
        setWhitelistContract();
    }

    function prepareFund() internal {
        vm.startPrank(alice, alice);

        // approve tokens
        IERC20(tokenA).safeApprove(address(bank), type(uint256).max);
        IERC20(tokenB).safeApprove(address(bank), type(uint256).max);

        // mint tokens
        deal(tokenA, alice, type(uint256).max);
        deal(tokenB, alice, type(uint256).max);

        vm.stopPrank();
    }

    function setWhitelistContract() internal {
        // set whitelist contract call
        address[] memory _contracts = new address[](1);
        address[] memory _origins = new address[](1);
        bool[] memory _statuses = new bool[](1);

        _contracts[0] = address(this);
        _origins[0] = alice;
        _statuses[0] = true;

        // NOTE: only ALPHA governor can set whitelist contract call
        vm.prank(bank.governor());
        bank.setWhitelistContractWithTxOrigin(_contracts, _origins, _statuses);

        // NOTE: only ALPHA executive can set allow contract call
        vm.prank(bank.exec());
        bank.setAllowContractCalls(true);
    }

    function testAll() public {
        uint256 positionId = testOpenPosition();
        testIncreasePosition(positionId);
        testReducePosition(positionId);
        // testGetPendingRewards(positionId);
        testHarvestRewards(positionId);
    }

    function testOpenPosition() public returns (uint256 positionId) {
        uint256 amtAUser = 10000;
        uint256 amtBUser = 10000;
        uint256 amtLPUser = 0;
        uint256 amtABorrow = 10000;
        uint256 amtBBorrow = 10000;
        uint256 amtLPBorrow = 0;
        uint256 amtAMin = 0;
        uint256 amtBMin = 0;

        // assume that user wants to open position by calling to integration contract
        // so integration contract will forward a request to HomoraBank further
        vm.startPrank(alice);
        positionId = openPosition(
            address(spell),
            AddLiquidityParams(
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
    }

    function testIncreasePosition(uint256 positionId) public {
        uint256 amtAUser = 10000; // supply tokenA
        uint256 amtBUser = 10000; // supply tokenB
        uint256 amtLPUser = 0; // supply LP
        uint256 amtABorrow = 10000; // borrow tokenA
        uint256 amtBBorrow = 10000; // borrow tokenB
        uint256 amtLPBorrow = 0; // borrow LP tokens (always 0 since LP for borrowing is disabled)
        uint256 amtAMin = 0; // min tokenA
        uint256 amtBMin = 0; // min tokenB

        vm.startPrank(alice);
        increasePosition(
            positionId,
            address(spell),
            AddLiquidityParams(
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
    }

    function testReducePosition(uint256 positionId) public {
        // get collateral information from position id
        (
            ,
            address collateralTokenAddress,
            uint256 collateralId,
            uint256 collateralAmount
        ) = bank.getPositionInfo(positionId);

        uint256 amtLPTake = collateralAmount; // withdraw 100% of position
        uint256 amtLPWithdraw = 100; // return only 100 LP to user
        uint256 amtARepay = type(uint256).max; // repay 100% of tokenA
        uint256 amtBRepay = type(uint256).max; // repay 100% of tokenA
        uint256 amtLPRepay = 0; // (always 0 since LP borrow is disallowed)
        uint256 amtAMin = 0; // amount of tokenA that user expects after withdrawal
        uint256 amtBMin = 0; // amount of tokenB that user expects after withdrawal

        vm.startPrank(alice);
        reducePosition(
            address(spell),
            positionId,
            RemoveLiquidityParams(
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
    }

    function testHarvestRewards(uint256 positionId) public {
        // increase block timestamp to calculate more rewards
        vm.warp(block.timestamp + 10000);

        vm.startPrank(alice);
        harvestRewards(address(spell), positionId);
        vm.stopPrank();
    }

    // function testGetPendingRewards(uint256 positionId) public {
    //     // increase block timestamp to calculate more rewards
    //     vm.warp(block.timestamp + 10000);
    //     uint256 pendingRewards = getPendingRewards(positionId);
    //     console2.log("pendingRewards:", pendingRewards);
    // }
}
