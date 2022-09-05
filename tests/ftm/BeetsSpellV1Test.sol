// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./UtilsFTM.sol";
import "../../contracts/ftm/pool/beets/BeetsSpellV1Integration.sol";
import "../../../../interfaces/ftm/IBankFTM.sol";
import "../../../../interfaces/ftm/beets/IBeetsPool.sol";
import "../../../../interfaces/ftm/beets/IBeetsVault.sol";
import "../../../../interfaces/ftm/beets/IBeetsSpellV1.sol";
import "../../../../interfaces/ftm/beets/IWMasterChefBeetsWorker.sol";

import "forge-std/console2.sol";

contract BeetsSpellV1Test is UtilsFTM {
    using SafeERC20 for IERC20;

    IBankFTM bank = IBankFTM(bankAddress);

    // TODO: change spell address you want
    IBeetsSpellV1 spell =
        IBeetsSpellV1(0xEeb9b7C60749fEC168ABE7382981428D6ac00C2F); // spell to interact with
    // TODO: change vault you want
    IBeetsVault vault = IBeetsVault(0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce); // beets vault

    // TODO: change masterchef pool id you want
    uint256 masterChefPoolId = 17; // Pool id of Beets MasterChef
    // TODO: change lp you want
    address lp = 0xf3A602d30dcB723A74a0198313a7551FEacA7DAc;

    BeetsSpellV1Integration integration;
    address[] tokens;
    bytes32 poolId; // Pool id of Beets vault

    function setUp() public override {
        super.setUp();

        // deploy integration contract
        integration = new BeetsSpellV1Integration(bank, vault);

        vm.label(address(spell), "spell");
        vm.label(address(lp), "lp");
        vm.label(address(integration), "integration");

        IBeetsPool pool = IBeetsPool(lp);
        poolId = pool.getPoolId();
        (tokens, , ) = vault.getPoolTokens(poolId);

        // prepare fund for user
        prepareFundV2(alice, tokens, lp, address(integration));

        // set whitelist that integration contract can call HomoraBank, otherwise tx will fail
        // NOTE: set whitelist contract must be executed from ALPHA governor
        setWhitelistContract(bank, alice, address(integration));

        // set credit limit that integration contract can be borrow with uncollateralized loan
        for (uint256 i = 0; i < tokens.length; i++) {
            setCreditLimit(
                bank,
                address(integration),
                tokens[i],
                type(uint256).max
            );
        }
    }

    function testAll() public {
        uint256 positionId = testOpenPosition();
        testIncreasePosition(positionId);
        testGetPendingRewards(positionId);
        testHarvestRewards(positionId);
        testReducePosition(positionId);
    }

    function testOpenPosition() public returns (uint256 positionId) {
        uint256[] memory amtsUser = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amtsUser[i] = (10 * 10**IERC20Metadata(tokens[i]).decimals());
        }

        uint256 amtLPUser = 100;

        uint256[] memory amtsBorrow = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amtsBorrow[i] = amtsUser[i];
        }

        uint256 amtLPBorrow = 0;
        uint256 minLPMint = 0;

        // user info before
        uint256[] memory userBalanceTokens_before = new uint256[](
            tokens.length
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
        }
        uint256 userBalanceLP_before = balanceOf(lp, alice);

        // assume that user wants to open position by calling to integration contract
        // so integration contract will forward a request to HomoraBank further

        // call contract
        vm.startPrank(alice);
        positionId = integration.openPosition(
            address(spell),
            BeetsSpellV1Integration.AddLiquidityParams(
                poolId,
                amtsUser,
                amtLPUser,
                amtsBorrow,
                amtLPBorrow,
                minLPMint,
                masterChefPoolId
            )
        );
        vm.stopPrank();

        // user info after
        uint256[] memory userBalanceTokens_after = new uint256[](tokens.length);
        for (uint256 i = 0; i < userBalanceTokens_after.length; i++) {
            userBalanceTokens_after[i] = balanceOf(tokens[i], alice);
        }
        uint256 userBalanceLP_after = balanceOf(lp, alice);

        for (uint256 i = 0; i < tokens.length; i++) {
            require(
                userBalanceTokens_before[i] > userBalanceTokens_after[i],
                "incorrect user balance of token"
            );
        }
        require(
            userBalanceLP_before > userBalanceLP_after,
            "incorrect user balance of lp"
        );
    }

    function testIncreasePosition(uint256 _positionId) public {
        uint256[] memory amtsUser = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amtsUser[i] = 1 * 10**IERC20Metadata(tokens[i]).decimals();
        }

        uint256 amtLPUser = 100;

        uint256[] memory amtsBorrow = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amtsBorrow[i] = amtsUser[i];
        }

        uint256 amtLPBorrow = 0;
        uint256 minLPMint = 0;

        // user info before
        uint256[] memory userBalanceTokens_before = new uint256[](
            tokens.length
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
        }
        uint256 userBalanceLP_before = balanceOf(lp, alice);

        // call contract
        vm.startPrank(alice);
        integration.increasePosition(
            _positionId,
            address(spell),
            BeetsSpellV1Integration.AddLiquidityParams(
                poolId,
                amtsUser,
                amtLPUser,
                amtsBorrow,
                amtLPBorrow,
                minLPMint,
                masterChefPoolId
            )
        );
        vm.stopPrank();

        // user info after
        uint256[] memory userBalanceTokens_after = new uint256[](tokens.length);
        for (uint256 i = 0; i < userBalanceTokens_after.length; i++) {
            userBalanceTokens_after[i] = balanceOf(tokens[i], alice);
        }
        uint256 userBalanceLP_after = balanceOf(lp, alice);

        for (uint256 i = 0; i < tokens.length; i++) {
            require(
                userBalanceTokens_before[i] > userBalanceTokens_after[i],
                "incorrect user balance of token"
            );
        }
        require(
            userBalanceLP_before > userBalanceLP_after,
            "incorrect user balance of lp"
        );
    }

    function testReducePosition(uint256 _positionId) public {
        // get collateral information from position id
        (, , , uint256 collateralAmount) = bank.getPositionInfo(_positionId);

        uint256 amtLPTake = collateralAmount; // withdraw 100% of position
        uint256 amtLPWithdraw = 100; // return only 100 LP to user

        uint256[] memory amtsRepay = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amtsRepay[i] = type(uint256).max; // repay 100% of tokenB
        }

        uint256 amtLPRepay = 0; // (always 0 since LP borrow is disallowed)

        uint256[] memory amtsMin = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amtsMin[i] = 0; // amount of token that user expects after withdrawal
        }

        // user info before
        uint256[] memory userBalanceTokens_before = new uint256[](
            tokens.length
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            userBalanceTokens_before[i] = balanceOf(tokens[i], alice);
        }
        uint256 userBalanceLP_before = balanceOf(lp, alice);

        // call contract
        vm.startPrank(alice);
        integration.reducePosition(
            address(spell),
            _positionId,
            BeetsSpellV1Integration.RemoveLiquidityParams(
                poolId,
                amtLPTake,
                amtLPWithdraw,
                amtsRepay,
                amtLPRepay,
                amtsMin
            )
        );
        vm.stopPrank();

        // user info after
        uint256[] memory userBalanceTokens_after = new uint256[](tokens.length);
        for (uint256 i = 0; i < userBalanceTokens_after.length; i++) {
            userBalanceTokens_after[i] = balanceOf(tokens[i], alice);
        }
        uint256 userBalanceLP_after = balanceOf(lp, alice);

        for (uint256 i = 0; i < tokens.length; i++) {
            require(
                userBalanceTokens_after[i] > userBalanceTokens_before[i],
                "incorrect user balance of token"
            );
        }
        require(
            userBalanceLP_after - userBalanceLP_before == amtLPWithdraw,
            "incorrect user balance of LP"
        );
    }

    function testHarvestRewards(uint256 _positionId) public {
        // increase block number to calculate more rewards
        vm.roll(block.number + 10000);

        // query position info from position id
        (, address collateralTokenAddress, , ) = bank.getPositionInfo(
            _positionId
        );

        IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(
            collateralTokenAddress
        );

        // find reward token address
        address rewardToken = address(wrapper.rewardToken());

        // user info before
        uint256 userBalanceReward_before = balanceOf(rewardToken, alice);

        // call contract
        vm.startPrank(alice);
        integration.harvestRewards(address(spell), _positionId);
        vm.stopPrank();

        // user info after
        uint256 userBalanceReward_after = balanceOf(rewardToken, alice);

        require(
            userBalanceReward_after > userBalanceReward_before,
            "incorrect user balance of reward token"
        );
    }

    function testGetPendingRewards(uint256 _positionId) public {
        // increase block number to calculate more rewards
        vm.roll(block.number + 10000);

        // call contract
        uint256 pendingRewards = integration.getPendingRewards(_positionId);
        require(pendingRewards > 0, "pending rewards should be more than 0");

        console2.log("pendingRewards:", pendingRewards);
    }
}
