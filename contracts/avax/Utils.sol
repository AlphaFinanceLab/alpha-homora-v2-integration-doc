// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "../../interfaces/avax/IBankAVAX.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract Utils is Test {
    IBankAVAX bank = IBankAVAX(0x376d16C7dE138B01455a51dA79AD65806E9cd694);

    address WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address ALPHAe = 0x2147EFFF675e4A4eE1C2f918d181cDBd7a8E208f;
    address USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    uint256 constant alicePk = 0xa11ce;
    uint256 constant liquidatorPk = 0x110;
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal liquidator = payable(vm.addr(liquidatorPk));

    function setUp() public virtual {
        vm.label(WAVAX, "WAVAX");
        vm.label(ALPHAe, "ALPHAe");
        vm.label(USDC, "USDC");
        vm.label(alice, "alice");
        vm.label(liquidator, "liquidator");
    }

    function almostEqual(uint256 a, uint256 b) internal pure returns (bool) {
        uint256 threshold = 1; // 0.01
        return
            a * 100 <= b * 100 + threshold * b &&
            a * 100 >= b * 100 - threshold * b;
    }

    function contains(address[] memory array, address value)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        return false;
    }

    function findIndex(address[] memory array, address value)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return i;
            }
        }
        revert("index not found");
    }
}
