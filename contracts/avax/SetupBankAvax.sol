// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/avax/IBankAVAX.sol";
import "./Utils.sol";

import "forge-std/Test.sol";

contract SetupBankAvax is Test, Utils {
    using SafeERC20 for IERC20;

    function setUp() public virtual override {
        super.setUp();

        vm.label(address(bank), "bank");

        // setup credit limit
    }
}
