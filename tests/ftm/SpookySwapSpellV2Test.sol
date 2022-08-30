// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./UtilsFTM.sol";
import "../../contracts/ftm/pool/spookyswap/SpookySwapSpellV2Integration.sol";
import "../../../../interfaces/ftm/IBankFTM.sol";
import "../../../../interfaces/ftm/spookyswap/ISpookySwapFactory.sol";
import "../../../../interfaces/ftm/spookyswap/ISpookySwapSpellV2.sol";
import "../../../../interfaces/ftm/spookyswap/IMasterChefBooV2.sol";
import "../../../../interfaces/ftm/spookyswap/IWMasterChefBooV2.sol";

import "forge-std/console2.sol";

contract SpookySwapSpellV2Test is UtilsFTM {
    using SafeERC20 for IERC20;

    IBankFTM bank = IBankFTM(bankAddress);

    // TODO: change spell address you want
    ISpookySwapSpellV2 spell =
        ISpookySwapSpellV2(0x04A65eaae1C6005a6522f5fd886F53Fce9F8a895); // spell to interact with
    ISpookySwapFactory factory =
        ISpookySwapFactory(0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3); // trader joe factory

    // TODO: change tokenA you want
    address tokenA = WFTM; // The first token of pool
    // TODO: change tokenB you want
    address tokenB = USDC; // The second token of pool
    // TODO: change pool id you want
    uint256 pid = 10; // Pool id of MasterchefBoo

    SpookySwapSpellV2Integration integration;
    address lp;

    function setUp() public override {
        super.setUp();

        vm.label(address(spell), "spell");

        // deploy integration contract
        integration = new SpookySwapSpellV2Integration(bank, factory);
        lp = factory.getPair(tokenA, tokenB);

        // prepare fund for user
        prepareFund(alice, tokenA, tokenB, lp, address(integration));

        // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
        // NOTE: set whitelist contract must be executed from ALPHA governor
        setWhitelistContract(bank, alice, address(integration));

        // set credit limit that integration contract can be borrow with uncollateralized loan
        setCreditLimit(bank, address(integration), tokenA, type(uint256).max);
        setCreditLimit(bank, address(integration), tokenB, type(uint256).max);
    }

    function testAll() public {
        uint256 positionId = testOpenPosition();
        testIncreasePosition(positionId);
        testGetPendingRewards(positionId);
        testHarvestRewards(positionId);
        testReducePosition(positionId);
    }

    function testOpenPosition() public returns (uint256 positionId) {
        uint256 amtAUser = 1 * 10**IERC20Metadata(tokenA).decimals();
        uint256 amtBUser = 1 * 10**IERC20Metadata(tokenB).decimals();
        uint256 amtLPUser = 100;
        uint256 amtABorrow = amtAUser;
        uint256 amtBBorrow = amtBUser;
        uint256 amtLPBorrow = 0;
        uint256 amtAMin = 0;
        uint256 amtBMin = 0;

        // user info before
        uint256 userBalanceTokenA_before = balanceOf(tokenA, alice);
        uint256 userBalanceTokenB_before = balanceOf(tokenB, alice);
        uint256 userBalanceLP_before = balanceOf(lp, alice);

        // assume that user wants to open position by calling to integration contract
        // so integration contract will forward a request to HomoraBank further

        // call contract
        vm.startPrank(alice);
        positionId = integration.openPosition(
            address(spell),
            SpookySwapSpellV2Integration.AddLiquidityParams(
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
        uint256 userBalanceTokenA_after = balanceOf(tokenA, alice);
        uint256 userBalanceTokenB_after = balanceOf(tokenB, alice);
        uint256 userBalanceLP_after = balanceOf(lp, alice);

        require(
            userBalanceTokenA_before > userBalanceTokenA_after,
            "incorrect user balance of tokenA"
        );
        require(
            userBalanceTokenB_before > userBalanceTokenB_after,
            "incorrect user balance of tokenB"
        );
        require(
            userBalanceLP_before > userBalanceLP_after,
            "incorrect user balance of lp"
        );
    }

    function testIncreasePosition(uint256 positionId) public {
        uint256 amtAUser = 1 * 10**IERC20Metadata(tokenA).decimals();
        uint256 amtBUser = 1 * 10**IERC20Metadata(tokenB).decimals();
        uint256 amtLPUser = 100;
        uint256 amtABorrow = amtAUser;
        uint256 amtBBorrow = amtBUser;
        uint256 amtLPBorrow = 0;
        uint256 amtAMin = 0;
        uint256 amtBMin = 0;

        // user info before
        uint256 userBalanceTokenA_before = balanceOf(tokenA, alice);
        uint256 userBalanceTokenB_before = balanceOf(tokenB, alice);
        uint256 userBalanceLP_before = balanceOf(lp, alice);

        // call contract
        vm.startPrank(alice);
        integration.increasePosition(
            positionId,
            address(spell),
            SpookySwapSpellV2Integration.AddLiquidityParams(
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
        uint256 userBalanceTokenA_after = balanceOf(tokenA, alice);
        uint256 userBalanceTokenB_after = balanceOf(tokenB, alice);
        uint256 userBalanceLP_after = balanceOf(lp, alice);

        require(
            userBalanceTokenA_before > userBalanceTokenA_after,
            "incorrect user balance of tokenA"
        );
        require(
            userBalanceTokenB_before > userBalanceTokenB_after,
            "incorrect user balance of tokenB"
        );
        require(
            userBalanceLP_before > userBalanceLP_after,
            "incorrect user balance of lp"
        );
    }

    function testReducePosition(uint256 positionId) public {
        // get collateral information from position id
        (, , , uint256 collateralAmount) = bank.getPositionInfo(positionId);

        uint256 amtLPTake = collateralAmount; // withdraw 100% of position
        uint256 amtLPWithdraw = 100; // return only 100 LP to user
        uint256 amtARepay = type(uint256).max; // repay 100% of tokenA
        uint256 amtBRepay = type(uint256).max; // repay 100% of tokenB
        uint256 amtLPRepay = 0; // (always 0 since LP borrow is disallowed)
        uint256 amtAMin = 0; // amount of tokenA that user expects after withdrawal
        uint256 amtBMin = 0; // amount of tokenB that user expects after withdrawal

        // user info before
        uint256 userBalanceTokenA_before = balanceOf(tokenA, alice);
        uint256 userBalanceTokenB_before = balanceOf(tokenB, alice);
        uint256 userBalanceLP_before = balanceOf(lp, alice);

        // call contract
        vm.startPrank(alice);
        integration.reducePosition(
            address(spell),
            positionId,
            SpookySwapSpellV2Integration.RemoveLiquidityParams(
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
        uint256 userBalanceTokenA_after = balanceOf(tokenA, alice);
        uint256 userBalanceTokenB_after = balanceOf(tokenB, alice);
        uint256 userBalanceLP_after = balanceOf(lp, alice);

        require(
            userBalanceTokenA_after > userBalanceTokenA_before,
            "incorrect user balance of tokenA"
        );
        require(
            userBalanceTokenB_after > userBalanceTokenB_before,
            "incorrect user balance of tokenB"
        );
        require(
            userBalanceLP_after - userBalanceLP_before == amtLPWithdraw,
            "incorrect user balance of LP"
        );
    }

    function testHarvestRewards(uint256 positionId) public {
        // increase block timestamp to calculate more rewards
        vm.warp(block.timestamp + 10000);

        // query position info from position id
        (, address collateralTokenAddress, , ) = bank.getPositionInfo(
            positionId
        );

        IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);

        // find reward token address
        address rewardToken = address(wrapper.rewardToken());

        // user info before
        uint256 userBalanceReward_before = balanceOf(rewardToken, alice);

        // call contract
        vm.startPrank(alice);
        integration.harvestRewards(address(spell), positionId);
        vm.stopPrank();

        // user info after
        uint256 userBalanceReward_after = balanceOf(rewardToken, alice);

        require(
            userBalanceReward_after > userBalanceReward_before,
            "incorrect user balance of reward token"
        );
    }

    function testGetPendingRewards(uint256 positionId) public {
        // increase block timestamp to calculate more rewards
        vm.warp(block.timestamp + 10000);

        // call contract
        uint256 pendingRewards = integration.getPendingRewards(positionId);
        require(pendingRewards > 0, "pending rewards should be more than 0");

        console2.log("pendingRewards:", pendingRewards);
    }
}
