// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';

import '../Utils.sol';
import '../../interfaces/eth/IBankETH.sol';

contract UtilsETH is Utils {
  using SafeERC20 for IERC20;

  address bankAddress = 0xba5eBAf3fc1Fcca67147050Bf80462393814E54B;

  address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
  address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address DPI = 0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b;
  address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

  //   address ALPHAe = 0x2147EFFF675e4A4eE1C2f918d181cDBd7a8E208f;
  //   address DAIe = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
  //   address USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
  //   address USDCe = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;

  function setUp() public virtual {
    vm.label(bankAddress, 'bankAddress');

    vm.label(CRV, 'WETH');
    vm.label(CRV, 'CRV');
  }

  function balanceOf(address token, address user) internal view returns (uint) {
    uint balance = IERC20(token).balanceOf(user);
    if (token == WETH) {
      return balance + address(user).balance;
    }
    return balance;
  }

  function setWhitelistContract(
    IBankETH _bank,
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
    IBankETH _bank,
    address _user,
    address _token,
    uint _limit,
    address _origin
  ) internal {
    IBankETH.CreditLimit[] memory creditLimits = new IBankETH.CreditLimit[](1);

    creditLimits[0] = IBankETH.CreditLimit(_user, _token, _limit, _origin);

    // NOTE: only ALPHA governor can set credit limit
    vm.prank(_bank.governor());
    _bank.setCreditLimits(creditLimits);
  }
}
