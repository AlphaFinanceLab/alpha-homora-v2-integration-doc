// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/avax/IBankAVAX.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract Utils is Test {
    using SafeERC20 for IERC20;

    IBankAVAX bank = IBankAVAX(0x376d16C7dE138B01455a51dA79AD65806E9cd694);

    address ALPHAe = 0x2147EFFF675e4A4eE1C2f918d181cDBd7a8E208f;
    address DAIe = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    address USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address USDCe = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;
    address WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address WBTCe = 0x50b7545627a5162F82A992c33b87aDc75187B218;

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

    function balanceOf(address token, address user)
        internal
        view
        returns (uint256)
    {
        uint256 balance = IERC20(token).balanceOf(user);
        if (token == WAVAX) {
            return balance + address(user).balance;
        }
        return balance;
    }
}