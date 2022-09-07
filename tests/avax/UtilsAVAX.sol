// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';

import '../Utils.sol';
import '../../interfaces/avax/IBankAVAX.sol';

contract UtilsAVAX is Utils {
  using SafeERC20 for IERC20;

  address bankAddress = 0x376d16C7dE138B01455a51dA79AD65806E9cd694;

  address ALPHAe = 0x2147EFFF675e4A4eE1C2f918d181cDBd7a8E208f;
  address DAIe = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
  address USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
  address USDCe = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;
  address WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
  address WBTCe = 0x50b7545627a5162F82A992c33b87aDc75187B218;

  function setUp() public virtual {
    vm.label(bankAddress, 'bankAddress');

    vm.label(WAVAX, 'WAVAX');
    vm.label(ALPHAe, 'ALPHAe');
    vm.label(USDC, 'USDC');
    vm.label(alice, 'alice');
    vm.label(liquidator, 'liquidator');
  }

  function balanceOf(address token, address user) internal view returns (uint) {
    uint balance = IERC20(token).balanceOf(user);
    if (token == WAVAX) {
      return balance + address(user).balance;
    }
    return balance;
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
    uint _limit,
    address _origin
  ) internal {
    IBankAVAX.CreditLimit[] memory creditLimits = new IBankAVAX.CreditLimit[](1);

    creditLimits[0] = IBankAVAX.CreditLimit(_user, _token, _limit, _origin);

    // NOTE: only ALPHA governor can set credit limit
    vm.prank(_bank.governor());
    _bank.setCreditLimits(creditLimits);
  }
}
