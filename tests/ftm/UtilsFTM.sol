// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../Utils.sol";
import "../../interfaces/ftm/IBankFTM.sol";

contract UtilsFTM is Utils {
    using SafeERC20 for IERC20;

    address bankAddress = 0x060E91A44f16DFcc1e2c427A0383596e1D2e886f;

    address BTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    address ETH = 0x74b23882a30290451A17c44f4F05243b6b58C76d;
    address USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    function setUp() public virtual {
        vm.label(bankAddress, "bank");

        vm.label(BTC, "BTC");
        vm.label(ETH, "ETH");
        vm.label(USDC, "USDC");
        vm.label(WFTM, "WFTM");
    }

    function balanceOf(address token, address user)
        internal
        view
        returns (uint256)
    {
        uint256 balance = IERC20(token).balanceOf(user);
        if (token == WFTM) {
            return balance + address(user).balance;
        }
        return balance;
    }

    function setWhitelistContract(
        IBankFTM _bank,
        address,
        address _contract
    ) internal {
        // set whitelist contract call
        address[] memory _contracts = new address[](1);
        bool[] memory _statuses = new bool[](1);

        _contracts[0] = _contract;
        _statuses[0] = true;

        // NOTE: only ALPHA governor can set whitelist contract call
        vm.prank(_bank.governor());
        _bank.setWhitelistUsers(_contracts, _statuses);

        // NOTE: only ALPHA executive can set allow contract call
        vm.prank(_bank.exec());
        _bank.setAllowContractCalls(true);
    }

    function setCreditLimit(
        IBankFTM _bank,
        address _user,
        address _token,
        uint256 _limit
    ) internal {
        IBankFTM.CreditLimit[] memory creditLimits = new IBankFTM.CreditLimit[](
            1
        );

        creditLimits[0] = IBankFTM.CreditLimit(_user, _token, _limit);

        // NOTE: only ALPHA governor can set credit limit
        vm.prank(_bank.governor());
        _bank.setCreditLimits(creditLimits);
    }
}
