// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../Utils.sol";

contract UtilsFTM is Utils {
    address bankAddress = 0x060E91A44f16DFcc1e2c427A0383596e1D2e886f;

    address USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    function setUp() public virtual {
        vm.label(bankAddress, "bank");

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
}
