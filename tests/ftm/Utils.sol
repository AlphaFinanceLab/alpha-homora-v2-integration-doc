// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract Utils is Test {
    using SafeERC20 for IERC20;

    address bank = 0x060E91A44f16DFcc1e2c427A0383596e1D2e886f;

    address USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    uint256 constant alicePk = 0xa11ce;
    uint256 constant liquidatorPk = 0x110;
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal liquidator = payable(vm.addr(liquidatorPk));

    function setUp() public virtual {
        vm.label(USDC, "USDC");
        vm.label(WFTM, "WFTM");
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
