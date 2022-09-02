// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "forge-std/Test.sol";

contract Utils is Test {
  using SafeERC20 for IERC20;

  uint256 constant alicePk = 0xa11ce;
  uint256 constant bobPk = 0xb0b;
  uint256 constant liquidatorPk = 0x110;
  address payable internal alice = payable(vm.addr(alicePk));
  address payable internal bob = payable(vm.addr(bobPk));
  address payable internal liquidator = payable(vm.addr(liquidatorPk));

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

  function prepareTokens(
    address _user,
    address _tokenA,
    address _tokenB,
    address _integration
  ) internal {
    vm.startPrank(_user, _user);

    // approve tokens
    IERC20(_tokenA).safeApprove(_integration, type(uint256).max);
    IERC20(_tokenB).safeApprove(_integration, type(uint256).max);

    // mint tokens
    deal(_tokenA, _user, 1_000 * 10**IERC20Metadata(_tokenA).decimals());
    deal(_tokenB, _user, 1_000 * 10**IERC20Metadata(_tokenB).decimals());

    vm.stopPrank();
  }

  function prepareFundV2(
    address _user,
    address[] memory _tokens,
    address _lp,
    address _integration
  ) internal {
    vm.startPrank(_user, _user);

    // approve tokens
    for (uint256 i = 0; i < _tokens.length; i++) {
      IERC20(_tokens[i]).safeApprove(_integration, type(uint256).max);
    }
    IERC20(_lp).safeApprove(_integration, type(uint256).max);

    // mint tokens
    for (uint256 i = 0; i < _tokens.length; i++) {
      deal(
        _tokens[i],
        _user,
        1_000 * 10**IERC20Metadata(_tokens[i]).decimals()
      );
    }
    deal(_lp, _user, 1000);

    vm.stopPrank();
  }
}
