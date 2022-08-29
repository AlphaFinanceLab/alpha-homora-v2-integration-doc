// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../contracts/avax/BaseIntegration.sol";

import "forge-std/Test.sol";

contract BaseTest is Test {
    using SafeERC20 for IERC20;

    function prepareFund(
        address _user,
        address _tokenA,
        address _tokenB,
        address _lp,
        address _integration
    ) internal {
        vm.startPrank(_user, _user);

        // approve tokens
        IERC20(_tokenA).safeApprove(_integration, type(uint256).max);
        IERC20(_tokenB).safeApprove(_integration, type(uint256).max);
        IERC20(_lp).safeApprove(_integration, type(uint256).max);

        // mint tokens
        deal(_tokenA, _user, 1_000 * 10**IERC20Metadata(_tokenA).decimals());
        deal(_tokenB, _user, 1_000 * 10**IERC20Metadata(_tokenB).decimals());
        deal(_lp, _user, 1000);

        vm.stopPrank();
    }

    function setWhitelistContract(
        IBankAVAX _bank,
        address _origin,
        address _contract
    ) internal {
        // set whitelist contract call
        address[] memory _contracts = new address[](1);
        address[] memory _origins = new address[](1);
        bool[] memory _statuses = new bool[](1);

        _contracts[0] = _contract;
        _origins[0] = _origin;
        _statuses[0] = true;

        // NOTE: only ALPHA governor can set whitelist contract call
        vm.prank(_bank.governor());
        _bank.setWhitelistContractWithTxOrigin(_contracts, _origins, _statuses);

        // NOTE: only ALPHA executive can set allow contract call
        vm.prank(_bank.exec());
        _bank.setAllowContractCalls(true);
    }

    function setCreditLimit(
        IBankAVAX _bank,
        address _user,
        address _token,
        uint256 _limit,
        address _origin
    ) internal {
        IBankAVAX.CreditLimit[]
            memory creditLimits = new IBankAVAX.CreditLimit[](1);

        creditLimits[0] = IBankAVAX.CreditLimit(_user, _token, _limit, _origin);

        // NOTE: only ALPHA governor can set credit limit
        vm.prank(_bank.governor());
        _bank.setCreditLimits(creditLimits);
    }
}
