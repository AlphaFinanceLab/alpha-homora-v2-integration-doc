// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';

import '../Utils.sol';
import '../../interfaces/op/IBankOP.sol';

contract UtilsOP is Utils {
  using SafeERC20 for IERC20;

  address bankAddress = 0xFFa51a5EC855f8e38Dd867Ba503c454d8BBC5aB9;

  address WETH = 0x4200000000000000000000000000000000000006;
  address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
  address USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
  address OP = 0x4200000000000000000000000000000000000042;

  function setUp() public virtual {
    vm.label(bankAddress, 'bankAddress');

    vm.label(WETH, 'WETH');
    vm.label(DAI, 'DAI');
    vm.label(USDC, 'USDC');
    vm.label(OP, 'OP');
    vm.label(alice, 'alice');
    vm.label(liquidator, 'liquidator');
  }

  function balanceOf(address token, address user) internal view returns (uint) {
    uint balance = IERC20(token).balanceOf(user);
    if (token == WETH) {
      return balance + address(user).balance;
    }
    return balance;
  }

  function setWhitelistContract(IBankOP _bank, address _contract) internal {
    // set whitelist contract call
    address[] memory _contracts = new address[](1);
    bool[] memory _statuses = new bool[](1);

    _contracts[0] = _contract;
    _statuses[0] = true;

    // NOTE: only ALPHA governor can set whitelist contract call
    vm.prank(_bank.governor());
    _bank.setWhitelistUsers(_contracts, _statuses);
  }

  function setWhitelistContractWithTxOrigin(
    IBankOP _bank,
    address _origin,
    address _contract
  ) internal {
    // set whitelist contract call from tx origin
    address[] memory _contracts = new address[](1);
    address[] memory _origins = new address[](1);
    bool[] memory _statuses = new bool[](1);

    _contracts[0] = _contract;
    _origins[0] = _origin;
    _statuses[0] = true;

    // NOTE: only ALPHA governor can set whitelist contract call
    vm.prank(_bank.governor());
    _bank.setWhitelistContractWithTxOrigin(_contracts, _origins, _statuses);
  }

  function setCreditLimit(
    IBankOP _bank,
    address _user,
    address _token,
    uint _limit,
    address _origin
  ) internal {
    IBankOP.CreditLimit[] memory creditLimits = new IBankOP.CreditLimit[](1);

    creditLimits[0] = IBankOP.CreditLimit(_user, _token, _limit, _origin);

    // NOTE: only ALPHA governor can set credit limit
    vm.prank(_bank.governor());
    _bank.setCreditLimits(creditLimits);
  }
}
