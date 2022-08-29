// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../contracts/avax/SetupBankAvax.sol";
import "../../contracts/avax/pool/traderjoe/TraderJoeSpellV3Integration.sol";
import "../../../../interfaces/avax/traderjoe/IUniswapV2Factory.sol";
import "../../../../interfaces/avax/traderjoe/ITraderJoeSpellV3.sol";
import "../../../../interfaces/avax/traderjoe/IBoostedMasterChefJoe.sol";
import "../../../../interfaces/avax/traderjoe/IWBoostedMasterChefJoeWorker.sol";

import "forge-std/console2.sol";

contract TraderJoeSpellV3Test is Test, Utils {
    using SafeERC20 for IERC20;

    // TODO: change spell address you want
    ITraderJoeSpellV3 spell =
        ITraderJoeSpellV3(0x28F1BdBc52Ad1aAab71660f4B33179335054BE6A); // spell to interact with
    IUniswapV2Factory factory =
        IUniswapV2Factory(0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10); // trader joe factory

    // TODO: change tokenA you want
    address tokenA = WAVAX; // The first token of pool
    // TODO: change tokenB you want
    address tokenB = USDC; // The second token of pool
    // TODO: change pool id you want
    uint256 pid = 0; // Pool id of BoostedMasterChefJoe

    TraderJoeSpellV3Integration integration;
    address lp;

    function setUp() public override {
        super.setUp();

        vm.label(address(spell), "spell");

        // deploy integration contract
        integration = new TraderJoeSpellV3Integration(factory);
        lp = factory.getPair(tokenA, tokenB);

        // prepare fund for user
        prepareFund();

        // set whitelist that this contract can call HomoraBank, otherwise tx will fail
        // NOTE: set whitelist contract must be executed from ALPHA governor
        setWhitelistContract();
    }

    function prepareFund() internal {
        vm.startPrank(alice, alice);

        // approve tokens
        IERC20(tokenA).safeApprove(address(integration), type(uint256).max);
        IERC20(tokenB).safeApprove(address(integration), type(uint256).max);
        IERC20(lp).safeApprove(address(integration), type(uint256).max);

        // mint tokens
        deal(tokenA, alice, 1_000 * 10**IERC20Metadata(tokenA).decimals());
        deal(tokenB, alice, 1_000 * 10**IERC20Metadata(tokenB).decimals());
        deal(lp, alice, 1000);

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
            TraderJoeSpellV3Integration.AddLiquidityParams(
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
            TraderJoeSpellV3Integration.AddLiquidityParams(
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
        (
            ,
            address collateralTokenAddress,
            uint256 collateralId,
            uint256 collateralAmount
        ) = bank.getPositionInfo(positionId);

        uint256 amtLPTake = collateralAmount; // withdraw 100% of position
        uint256 amtLPWithdraw = 0; // return only 100 LP to user
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
            TraderJoeSpellV3Integration.RemoveLiquidityParams(
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
        (
            ,
            address collateralTokenAddress,
            uint256 collateralId,
            uint256 collateralAmount
        ) = bank.getPositionInfo(positionId);

        IWBoostedMasterChefJoeWorker wrapper = IWBoostedMasterChefJoeWorker(
            collateralTokenAddress
        );

        // find reward token address
        address rewardToken = address(wrapper.joe());

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

        console2.log("pendingRewards:", pendingRewards);
    }
}
