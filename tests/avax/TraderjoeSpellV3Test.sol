// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../contracts/avax/SetupBankAvax.sol";
import "../../contracts/avax/pool/traderjoe/TraderJoeV3Integration.sol";
import "../../../../interfaces/avax/ITraderJoeSpellV3.sol";
import "../../../../interfaces/avax/IBoostedMasterChefJoe.sol";
import "../../../../interfaces/avax/IWBoostedMasterChefJoeWorker.sol";

import "forge-std/console2.sol";

contract TraderJoeSpellV3Test is TraderJoeV3Integration {
    using SafeERC20 for IERC20;

    ITraderJoeSpellV3 spell =
        ITraderJoeSpellV3(0x28F1BdBc52Ad1aAab71660f4B33179335054BE6A);

    address tokenA = WAVAX;
    address tokenB = USDC;

    function setUp() public override {
        super.setUp();

        vm.label(address(spell), "spell");

        // prepare fund
        prepareFund();

        // whitelist contract
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

        vm.prank(bank.governor());
        bank.setWhitelistContractWithTxOrigin(_contracts, _origins, _statuses);

        vm.prank(bank.exec());
        bank.setAllowContractCalls(true);
    }

    function testAll() public {
        uint256 positionId = testOpenPosition();
        testIncreasePosition(positionId);
        testReducePosition(positionId);
        testGetPendingRewards(positionId);
        testHarvestRewards(positionId);
    }

    function testOpenPosition() public returns (uint256 positionId) {
        uint256 amtAUser = 10000; // supply tokenA
        uint256 amtBUser = 10000; // supply tokenB
        uint256 amtLPUser = 0; // supply LP
        uint256 amtABorrow = 10000; // borrow tokenA
        uint256 amtBBorrow = 10000; // borrow tokenB
        uint256 amtLPBorrow = 0; // borrow LP tokens (always 0 since LP for borrowing is disabled)
        uint256 amtAMin = 0; // min tokenA
        uint256 amtBMin = 0; // min tokenB
        uint256 pid = 0;

        vm.startPrank(alice);
        positionId = openPosition(
            address(spell),
            TraderJoeV3Integration.AddLiquidityParams(
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
        uint256 pid = 0;

        vm.startPrank(alice, alice);
        increasePosition(
            address(spell),
            positionId,
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
        (
            ,
            address collateralTokenAddress,
            uint256 collateralId,
            uint256 collateralAmount
        ) = bank.getPositionInfo(positionId);

        uint256 amtLPTake = collateralAmount; // Take out LP token amount (from Homora)
        uint256 amtLPWithdraw = 100; // Withdraw LP token amount (back to user)
        uint256 amtARepay = type(uint256).max; // Repay tokenA amount (repay all -> type(uint).max)
        uint256 amtBRepay = type(uint256).max; // Repay tokenB amount (repay all -> type(uint).max)
        uint256 amtLPRepay = 0; // Repay LP token amount
        uint256 amtAMin = 0; // Desired tokenA amount
        uint256 amtBMin = 0; // Desired tokenB amount

        vm.startPrank(alice, alice);
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
        vm.startPrank(alice, alice);
        harvestRewards(address(spell), positionId);
        vm.stopPrank();
    }

    function testGetPendingRewards(uint256 positionId) public {
        vm.warp(block.timestamp + 10000);
        uint256 pendingRewards = getPendingRewards(positionId);
        console2.log("pendingRewards:", pendingRewards);
    }

    function testReinvest() public {}
}
