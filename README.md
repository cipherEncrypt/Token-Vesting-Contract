# Token Vesting

ERC-20 vesting wallet with a **cliff** (nothing vests before it) and **linear vesting** after. The beneficiary calls `release()` to claim whatever has unlocked.

Built with Foundry + OpenZeppelin. Solidity `^0.8.20`.

## How it works

```
Before cliff ends     → 0 vested
After full duration   → 100% vested
In between            → totalAllocation × (elapsed / vestingDuration)
```

Where `elapsed = timestamp - start` and `totalAllocation = token.balance + released`.

**Important nuance:** the linear clock starts at `start`, not at cliff end. The cliff is a release gate, not a vesting reset. When the cliff expires, `cliffDuration / vestingDuration` of tokens are already vested and immediately claimable.

## Project layout

```
src/VestingWallet.sol   — core vesting logic
src/MockERC20.sol       — mintable test token
test/VestingWallet.t.sol
script/Deploy.s.sol
```

## Quick start

```bash
# install deps (if cloning fresh)
forge install

# build + test
forge build
forge test -vvv
```

## Design decisions

| Choice | Why |
|--------|-----|
| `immutable` params | Cheaper reads, schedule can't change after deploy |
| `released` before transfer | CEI pattern — blocks reentrancy via token callbacks |
| `SafeERC20` | Handles tokens that don't return `bool` on transfer |
| `vestedAmount(timestamp)` param | Testable without `vm.warp` everywhere |
| `totalAllocation()` dynamic | Top-up transfers extend the schedule automatically |
| `require(amount > 0)` on release | Clear revert instead of silent no-op |

## Deploy to Sepolia

1. Copy env template:

```bash
cp .env.example .env
```

2. Fill in your values (RPC URL, funded private key, beneficiary address).

3. Broadcast:

```bash
source .env
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Add `--verify --etherscan-api-key $ETHERSCAN_API_KEY` to verify on Etherscan.

### Deployed contract (Sepolia)

| Contract | Address |
|----------|---------|
| VestingWallet | [0xDE43c4FE037184812bBB5aD7Fe3fa26ADB026396](https://sepolia.etherscan.io/address/0xDE43c4FE037184812bBB5aD7Fe3fa26ADB026396) |
| MockERC20 (VEST) | [0x7Ed5a71d6236a76e15aeC7d04312065f362cB9B0](https://sepolia.etherscan.io/address/0x7Ed5a71d6236a76e15aeC7d04312065f362cB9B0) |
| Beneficiary | `0xd3e989A7864c1643588145E465845a0F121804c6` |

Allocation: 1,000,000 VEST. Schedule started Nov 2023 — fully vested now; call `release()` to claim.

## Interview talking points

- **Why update `released` before transfer?** Checks-effects-interactions. If the token triggers a callback (ERC-777), state is already correct — a reentrant `release()` sees the updated `released` and can't double-pay.
- **Why linear from `start` not cliff end?** Industry-standard (OpenZeppelin uses the same model). Alternative: vest only over `(vestingDuration - cliffDuration)` after cliff — different economics, document which you picked.
- **What if more tokens are sent to the contract?** `totalAllocation()` grows; vesting math scales to the new total. No admin function needed.

## License

MIT
![Solidity](https://img.shields.io/badge/Solidity-0.8.20-363636)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000)
![Tests](https://img.shields.io/badge/tests-13%20passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
