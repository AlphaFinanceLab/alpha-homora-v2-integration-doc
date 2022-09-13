# FAQ

## Revert message

1. Revert with message `!credit limit` when openning a position

   - We limit the borrow credit if the caller is a contract (not EOA). you can call `setWhitelistUsers` and `setCreditLimits` to grant borrow credit to the contract.

2. Revert with message `incorrect LP token.` when openning a position

   - It happens when you use an incorrect spell. Please see which spell contract should be use from the doc.

3. Revert with message `refund ETH failed` when openning or closing a position

   - It happens when the contract try to send a leftover (native ETH) to the caller but the caller cannot recieve them due to no `recieve` function.

4. Revert with message `bad cast call` when openning or closing a position

   - It shows this message because it cannot extract internal error. The best way to investigate is by running forge and look into the stack trace.

5. Revert with message `insufficient cash` when openning or closing a position

   - It happens when the amount tokens user want to borrow is more than the token amount available in the lending pool. To resolve the issue on fork-environment is to lend the tokens to the pool.

## Contract functionality

1. which view function is able to get the number of LP tokens in a Homora position?
   - you can use the amount of wrapper tokens from function `bank.getPositionInfo`. The number of wrapper tokens is equivalent to the number of LP tokens that the position holds.

```
(_, _ , _, num_tokens) = HomoraBank.getPositionInfo(position_id)
```

2. Why does calling `setCreditLimit` function on fork environment fail?

   - It may be because we haven't called `setWhitelistUsers` before calling `setCreditLimit` or use incorrect ABI (there are different interfaces on some chains).

3. Why the same amount of collateral does not allow the same amount of borrow for both tokens (e.g. DAI vs ETH)?

   - The factor of the borrow token is different from its volatility. We allow to borrow more if it is more stable.

## Verifying contract

1. Contract code in [public repo](https://github.com/AlphaFinanceLab/alpha-homora-v2-contract) is not align with ABI file in gitbook.

   - The latest version of Homora contracts are in private repo. The ABI should be up to date. If not, feel free to contact us.

2. Is there any spot where we can see the verified contracts? Notice on production many contracts aren’t verified.
   - Unfortunately, there isn't. It's intended that we don't verify the contracts, for security reasons (to be on a safer side).
   - However, the component flow + implementation should follow closely to the public repo. The diff is mainly supporting new pool types, more checks, gas opts, etc.
