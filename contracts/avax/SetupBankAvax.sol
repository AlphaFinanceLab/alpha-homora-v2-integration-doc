// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/avax/IBankAVAX.sol";

import "./Utils.sol";

import "forge-std/Test.sol";

contract SetupBankAvax {
    using SafeERC20 for IERC20;

    IBankAVAX bank = IBankAVAX(0x376d16C7dE138B01455a51dA79AD65806E9cd694);

    constructor() {
        // setup credit limit
    }
}
