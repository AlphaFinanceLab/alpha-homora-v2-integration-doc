# Alpha Homora Contract Documentation

Alpha Homora is a decentralize leverage yield farming product. We allow users to lever up their yield farming position by borrowing external liquidity from the lending protocol.

Users can open leveraged positions, add more liquidity, harvest their positions, and remove their liquidity.

# Alpha Homora Components

Alpha Homora product is mainly composed of 5 components

1. Homora Bank Contract
   - is the main contract where stores user's positions and tracks the borrowing tokens.
2. Homora Spell Contracts
   - interact with DEX and the wrapper contract to open/add/remove/close users' positions.
3. Homora Wrapper Contracts
   - handle the farming process (i.e. deposit into Masterchef contract).
   - Wrap/Unwrap user's collateral and forward wrapped tokens to bank/spells.
4. Homora Oracle Contracts
   - Identify position values and token price
5. Homora SafeBox Contracts
   - allow users to lend tokens and earn lending interest (interest rate is reflected from how much user borrow the token).

![](https://i.imgur.com/yjEmemi.png)

# Interact with Alpha Homora Product

Note: the following example scripts are python langauge based on Brownie framework.

Farming on different DEX protocols uses different spell contracts. To interact with HomoraBank, you need to know which DEX protocol to farm (i.e. Uniswap, Sushiswap or Curve) and correctly map with the spell contract.

![](https://i.imgur.com/cizves9.png)

### Execute

You can open/adjust with the position via the bank contract by calling `bank.execute(position_id, spell_address, data)` function.

- `position_id`: your position Id, set it to be 0 if you want to open a new position.
- `spell_address`: spell contract address that interacts with your target DEX.
- `data`: describes what parameters we use and what function we call in the spell contract, encoded as bytes data.

After execution, it will return your `position_id`. (It must be equal to what you input or new `position_id` if you set it as 0).

**Example**: open position on Sushiswap (ETH; brownie script, python).

```python=
bank = HomoraBank.at("0xba5eBAf3fc1Fcca67147050Bf80462393814E54B")
spell = SushiswapSpellV1.at("0xdc9c7a2bae15dd89271ae5701a6f4db147baa44c") # spell
token_a = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
token_b = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" # WETH
amount_a_in = 1000 * 10 ** 6 # user's token_a provided amount
amount_b_in = 10 ** 18 # user's token_b provided amount
amount_lp_in = 0 # user's lp provided amount
amount_a_borrow = 1000 * 10 ** 6 # token_a borrow amount
amount_b_borrow = 0 # token_b borrow amount
amount_lp_borrow = 0 # LP borrow amount (always 0 since not support)
min_token_a_used = 0 # minimum token_a used (slippage)
min_token_b_used = 0 # minimum token_b used (slippage)
pool_id = 1 # pool id to farm on MasterChef

# Before execute, make sure you allow bank to transfer tokens from your wallet.
# Make sure you control your slippage correctly.
position_id = bank.execute(
    0, # position_id (0 for opening new position)
    spell,  # spell_address
    spell.addLiquidityWMasterChef.encode_input(
        token_a,
        token_b,
        [
            amount_a_in,
            amount_b_in,
            amount_lp_in,
            amount_a_borrow,
            amount_b_borrow,
            amount_lp_borrow,
            min_token_a_used,
            min_token_b_used,
        ],
        pool_id,
    ), # data
    {"from": user},
)
```

which is equivalent to

```python=
bank = HomoraBank.at("0xba5eBAf3fc1Fcca67147050Bf80462393814E54B")
spell = SushiswapSpellV1.at("0xdc9c7a2bae15dd89271ae5701a6f4db147baa44c") # spell
bank.execute(
    0, # position_id (0 for opening new position)
    spell,  # spell_address
    "0xe07d904e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000003b9aca000000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003b9aca0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", # data
    {"from": user},
)
```

You can provide native tokens instead of wrapped tokens.

```python=
bank.execute(
    0, # position_id (0 for opening new position)
    spell,  # spell_address
    spell.addLiquidityWMasterChef.encode_input(
        token_a,
        token_b,
        [
            amount_a_in,
            0,
            amount_lp_in,
            amount_a_borrow,
            amount_b_borrow,
            amount_lp_borrow,
            min_token_a_used,
            min_token_b_used,
        ],
        pool_id,
    ), # data
    {"from": user, "value": amount_b_in},
)
```

**Example**: remove liquidity from position on Cruve (ETH; brownie script, python).

Note that if you define repay amount to be `2**256-1` or `type(uint).max` in solidity, it means that you want to repay all debt of that token.

```python=
bank = HomoraBank.at("0xba5eBAf3fc1Fcca67147050Bf80462393814E54B")
spell = CurveSpellV1.at("0x8b947D8448CFFb89EF07A6922b74fBAbac219795") # spell

position_id = 2203
lp = "0x6c3f90f043a72fa612cbac8115ee7e52bde6e490"
# token0 = "0x6b175474e89094c44da98b954eedeac495271d0f"
# token1 = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
# token2 = "0xdac17f958d2ee523a2206206994597c13d831ec7"

lp_take = 10**18 # LP amount to take out of Homora
lp_withdraw = lp_take_amt // 10 # LP amount being transferred to wallet
repay_token0 = 2**256-1 # repay token0; repay all tokens
repay_token1 = 0 # repay token1
repay_token2 = 0 # repay token2
lp_repay = 0 # repay lp token; should be 0
min_amt0 = 0 # min amount token0
min_amt1 = 0 # min amount token1
min_amt2 = 0 # min amount token2

bank.execute(
    pos_id,
    spell,
    curve_spell.removeLiquidity3.encode_input(
        lp,
        lp_take,
        lp_withdraw,
        [repay_token0, repay_token1, repay_token2],
        lp_repay,
        [min_amt0, min_amt1, min_amt2],
    ),
    {"from": user},
)
```

Different DEXes require different inputs, please see section [here](#DEXes-amp-Interaction-types)

### Query function

#### getPositionInfo

`bank.getPositionInfo(position_id)`

Query the information of the position. It returns the following information (in order)

- `owner`: owner of the position.
- `collateral_token`: type of collateral token (wrapper contract)
- `collateral_id`: id of the collateral token
- `collateral_amount`: collateral amount.

Note that collateral ID may be changed everytime you adjust the position.

#### getCollateralETHValue

`bank.getCollateralETHValue(position_id)`

Get the total collateral value of the given position in ETH. It returns the following information

- `collateral_eth_value`: position's collateral value (in unit of ETH)

#### getBorrowETHValue

`bank.getBorrowETHValue(position_id)`

Get the total borrow value of the given position in ETH. It returns the following information

- `borrow_eth_value`: position's borrow value (in unit of ETH). The borrow value is accrued to only the bank's last interactions. **Note that the debts have not been accrued to the current state.**

#### getPositionDebts

`bank.getCollateralETHValue(position_id)`

Return the list of all debts for the given position id. It returns the following information (in order)

- `borrow_tokens`: list of tokens that being borrowed in this position.
- `debt_amounts`: list of debts of each tokens. These debts are accrued to only the bank's last interactions. **Note that the debts have not been accrued to the current state.**

#### borrowBalanceStored

`bank.borrowBalanceStored(position_id, borrow_token)`

Return the borrow balance for given position and token without triggering interest accrual. It returns the following information

- `debt`: position's debt from the given `borrowed_token` **Note that the debts have not been accrued to the current state.**

#### borrowBalanceCurrent

`bank.borrowBalanceCurrent(position_id, borrow_token)`

Trigger interest accrual and return the current borrow balance. Because of taking accrual into account, **This function uses gas to execute** (change storaged value). Better to call function only, not send transaction. It returns the following information

- `debt`: position's debt from the given `borrowed_token`

#### getBankInfo

`bank.getBankInfo(borrow_token)`

This query is for borrowing information. It returns the following information (in order)

- `isListed`: The flag whether Homora know this market.
- `cToken`: The CToken to draw liquidity from.
- `reserve`: The reserve portion allocated to Homora protocol.
- `totalDebt`: The total debt since bank's last action.
- `totalShare`: The total debt share count across all open positions.

### DEXes & Interaction types

As mentioned earlier, parameter inputs for `bank.execute()` depends on DEXes on each chain and type of the interaction. Please check the following links to see how to call the function properly.

- [Interact with HomoraV2 on Eth](./docs/homoraETH.md)
- [Interact with HomoraV2 on Avax](./docs/homoraAVAX.md)
- [Interact with HomoraV2 on Fantom](./docs/homoraFTM.md)
- [Interact with HomoraV2 on Optimism](./docs/homoraOP.md)
