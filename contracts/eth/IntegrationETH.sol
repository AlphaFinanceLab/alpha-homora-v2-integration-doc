// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import '../../interfaces/eth/IBankETH.sol';

contract IntegrationETH {
    IBankETH bank;
    constructor(IBankETH _bank) {
        _bank = bank;
    }

    function addLiquidity() external {}

}