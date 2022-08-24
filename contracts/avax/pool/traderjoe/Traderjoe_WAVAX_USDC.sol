// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../SetupBankAvax.sol";
import "../../../../interfaces/avax/ITraderJoeSpellV3.sol";
import "../../../../interfaces/avax/IBoostedMasterChefJoe.sol";
import "../../../../interfaces/avax/IWBoostedMasterChefJoeWorker.sol";

import "forge-std/console2.sol";

contract TraderJoe_WAVAX_ALPHAe is SetupBankAvax {
    using SafeERC20 for IERC20;

    ITraderJoeSpellV3 spell =
        ITraderJoeSpellV3(0x28F1BdBc52Ad1aAab71660f4B33179335054BE6A);

    function setUp() public override {
        super.setUp();

        vm.label(address(spell), "spell");
    }

    function testOpenPosition() public {
        address token0 = WAVAX;
        address token1 = USDC;
        uint256 amount0 = 10000; // supply token0
        uint256 amount1 = 10000; // supply token1
        uint256 amount_lp = 0; // supply LP
        uint256 amount0_borrow = 10000; // borrow token0
        uint256 amount1_borrow = 10000; // borrow token1
        uint256 amount_lp_borrow = 0; // borrow LP tokens (always 0 since LP for borrowing is disabled)
        uint256 min_token0 = 0; // min token0
        uint256 min_token1 = 0; // min token1
        uint256 pid = 0;

        vm.startPrank(alice, alice);

        // approve tokens
        IERC20(token0).safeApprove(address(bank), type(uint256).max);
        IERC20(token1).safeApprove(address(bank), type(uint256).max);

        // mint tokens
        deal(token0, alice, type(uint256).max);
        deal(token1, alice, type(uint256).max);

        bank.execute(
            0, // (0 is reserved for opening new position)
            address(spell),
            abi.encodeWithSelector(
                spell.addLiquidityWMasterChef.selector,
                token0,
                token1,
                ITraderJoeSpellV3.Amounts(
                    amount0,
                    amount1,
                    amount_lp,
                    amount0_borrow,
                    amount1_borrow,
                    amount_lp_borrow,
                    min_token0,
                    min_token1
                ),
                pid
            )
        );
        vm.stopPrank();
    }

    function testIncreasePosition() public {}

    function testReducePosition() public {}

    function testHarvestRewards() public {}

    function testGetPendingRewards() public {
        vm.warp(block.timestamp + 100000);

        uint256 positionId = bank.nextPositionId() - 1;

        (, address coll_token_addr, uint256 coll_id, uint256 coll_amt) = bank
            .getPositionInfo(positionId);

        IWBoostedMasterChefJoeWorker wrapper = IWBoostedMasterChefJoeWorker(
            coll_token_addr
        );
        IBoostedMasterChefJoe chef = IBoostedMasterChefJoe(wrapper.chef());

        (uint256 pid, uint256 start_token_per_share) = wrapper.decodeId(
            coll_id
        );

        uint256 end_token_per_share = wrapper.accJoePerShare();
        IBoostedMasterChefJoe.UserInfo memory userInfo = chef.userInfo(
            pid,
            address(wrapper)
        );
        (uint256 pendingJoe, , , ) = chef.pendingTokens(pid, address(wrapper));
        uint256 decimals = IERC20Metadata(address(wrapper.joe())).decimals();

        uint256 pendingJoePerShareFromChef = (pendingJoe * 10**18) /
            userInfo.amount;
        uint256 pending_rewards = (coll_amt *
            (end_token_per_share -
                start_token_per_share +
                pendingJoePerShareFromChef)) /
            10**18 /
            decimals;
        console2.log(pending_rewards);
    }

    function testReinvest() public {}
}
