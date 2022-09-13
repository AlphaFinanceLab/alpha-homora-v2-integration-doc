// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '../BaseIntegration.sol';
import '../utils/HomoraMath.sol';
import '../../interfaces/homorav2/banks/IBankFTM.sol';
import '../../interfaces/homorav2/spells/IBeetsSpellV1.sol';
import '../../interfaces/homorav2/wrappers/IWMasterChefBeetsWorker.sol';
import '../../interfaces/beets/IMasterChefBeets.sol';
import '../../interfaces/beets/IBeetsVault.sol';

import 'forge-std/console2.sol';

contract BeetsSpellV1IntegrationFtm is BaseIntegration {
  using SafeERC20 for IERC20;
  using HomoraMath for uint;

  IBankFTM bank; // homora bank
  IBeetsVault vault; // beets vault
  uint constant PRECISION = 10**18;

  struct AddLiquidityParams {
    bytes32 vaultPoolId; // poolId in Vault
    uint[] amtsUser; // Supplied tokens amount
    uint amtLPUser; // Supplied LP token amount
    uint[] amtsBorrow; // Borrow tokens amount
    uint amtLPBorrow; // Borrow LP token amount
    uint minLPMint; // Desired LP token amount (slippage control)
    uint chefPoolId; // pool id of BoostedMasterChefReward
  }

  struct RemoveLiquidityParams {
    bytes32 vaultPoolId; // poolId in Vault
    uint amtLPTake; // Amount of LP being removed from the position
    uint amtLPWithdraw; // Amount of LP that user receives (remainings are converted to underlying tokens).
    uint[] amtsRepay; // Amount of tokens that user repays (repay all -> type(uint).max)
    uint amtLPRepay; // Amount of LP that user repays (should be 0, not support borrowing LP tokens).
    uint[] amtsMin; // Desired tokens amount (slippage control)
  }

  constructor(IBankFTM _bank, IBeetsVault _factory) {
    bank = _bank;
    vault = _factory;
  }

  function openPosition(IBeetsSpellV1 _spell, AddLiquidityParams memory _params)
    external
    returns (uint positionId)
  {
    (address[] memory tokens, address lp) = getPoolTokensAndLp(_params.vaultPoolId);

    // approve tokens
    for (uint i = 0; i < tokens.length; i++) {
      ensureApprove(tokens[i], address(bank));
    }
    ensureApprove(lp, address(bank));

    // transfer tokens from user
    for (uint i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    IERC20(lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.addLiquidityWMasterChef.selector,
      _params.vaultPoolId,
      IBeetsSpellV1.Amounts(
        _params.amtsUser,
        _params.amtLPUser,
        _params.amtsBorrow,
        _params.amtLPBorrow,
        _params.minLPMint
      ),
      _params.chefPoolId
    );
    // (0 is reserved for opening new position)
    positionId = bank.execute(0, address(_spell), executeData);

    doRefundETH();
    for (uint i = 0; i < tokens.length; i++) {
      doRefund(tokens[i]);
    }
    doRefund(lp);
  }

  function increasePosition(
    uint _positionId,
    IBeetsSpellV1 _spell,
    AddLiquidityParams memory _params
  ) external {
    (address[] memory tokens, address lp) = getPoolTokensAndLp(_params.vaultPoolId);
    address rewardToken = getRewardToken(_positionId);

    // approve tokens
    for (uint i = 0; i < tokens.length; i++) {
      ensureApprove(tokens[i], address(bank));
    }
    ensureApprove(lp, address(bank));

    // transfer tokens from user
    for (uint i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _params.amtsUser[i]);
    }
    IERC20(lp).safeTransferFrom(msg.sender, address(this), _params.amtLPUser);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.addLiquidityWMasterChef.selector,
      _params.vaultPoolId,
      IBeetsSpellV1.Amounts(
        _params.amtsUser,
        _params.amtLPUser,
        _params.amtsBorrow,
        _params.amtLPBorrow,
        _params.minLPMint
      ),
      _params.chefPoolId
    );
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    for (uint i = 0; i < tokens.length; i++) {
      doRefund(tokens[i]);
    }
    doRefund(lp);
    doRefund(rewardToken);
  }

  function reducePosition(
    uint _positionId,
    IBeetsSpellV1 _spell,
    RemoveLiquidityParams memory _params
  ) external {
    (address[] memory tokens, address lp) = getPoolTokensAndLp(_params.vaultPoolId);
    address rewardToken = getRewardToken(_positionId);

    bytes memory executeData = abi.encodeWithSelector(
      _spell.removeLiquidityWMasterChef.selector,
      _params.vaultPoolId,
      IBeetsSpellV1.RepayAmounts(
        _params.amtLPTake,
        _params.amtLPWithdraw,
        _params.amtsRepay,
        _params.amtLPRepay,
        _params.amtsMin
      )
    );
    bank.execute(_positionId, address(_spell), executeData);

    doRefundETH();
    for (uint i = 0; i < tokens.length; i++) {
      doRefund(tokens[i]);
    }
    doRefund(lp);
    doRefund(rewardToken);
  }

  function harvestRewards(uint _positionId, IBeetsSpellV1 _spell) external {
    bytes memory executeData = abi.encodeWithSelector(_spell.harvestWMasterChef.selector);
    bank.execute(_positionId, address(_spell), executeData);

    address rewardToken = getRewardToken(_positionId);

    doRefund(rewardToken);
  }

  function getPendingRewards(uint _positionId) external view returns (uint pendingRewards) {
    // query position info from position id
    (, address collateralTokenAddress, uint collateralId, uint collateralAmount) = bank
      .getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);
    IMasterChefBeets chef = IMasterChefBeets(wrapper.chef());

    // get info for calculating rewards
    (uint chefPoolId, uint startRewardTokenPerShare) = wrapper.decodeId(collateralId);
    uint endRewardTokenPerShare = wrapper.accRewardPerShare();
    (uint totalSupply, ) = chef.userInfo(chefPoolId, address(wrapper)); // total lp from wrapper deposited in Chef

    // pending rewards separates into two parts
    // 1. pending rewards that are in the wrapper contract
    // 2. pending rewards that wrapper hasn't claimed from Chef's contract
    uint pendingRewardFromChef = chef.pendingBeets(chefPoolId, address(wrapper));
    endRewardTokenPerShare += (pendingRewardFromChef * PRECISION) / totalSupply;

    uint stReward = (startRewardTokenPerShare * collateralAmount).divCeil(PRECISION);
    uint enReward = (endRewardTokenPerShare * collateralAmount) / PRECISION;

    pendingRewards = (enReward > stReward) ? enReward - stReward : 0;
  }

  function getPoolTokensAndLp(bytes32 _vaultPoolId)
    internal
    view
    returns (address[] memory tokens, address lp)
  {
    (lp, ) = vault.getPool(_vaultPoolId);
    (tokens, , ) = vault.getPoolTokens(_vaultPoolId);
  }

  function getRewardToken(uint _positionId) internal view returns (address rewardToken) {
    // get collateral information from position id
    (, address collateralTokenAddress, , ) = bank.getPositionInfo(_positionId);

    IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);

    // find reward token address
    rewardToken = address(wrapper.rewardToken());
  }
}
