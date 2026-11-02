# Flash Loan — One Block or Nothing

> Borrow everything the vault holds, use it inside one transaction, and repay plus a fee - or the whole transaction reverts as if nothing happened. One block or nothing.

## What it does

Borrow everything the vault holds, use it inside one transaction, and repay plus a fee - or the whole transaction reverts as if nothing happened. One block or nothing. The entire lifecycle lives in one contract, every button in the UI calls a real function on it — there is no mock backend.

## Contract

| | |
|---|---|
| File | `contracts/FlashLoan.sol` |
| Contract name | `FlashLoan` (inherits `ReentrancyGuard, Ownable`) |
| Solidity | `^0.8.20` |
| State functions | 8 (of which 1 payable) |
| Deployed (mainnet 677) | not yet deployed — placeholder `0x000…000` |

### Function surface

| Function | Type | Returns |
|---|---|---|
| `owner` | view | address |
| `setDefaultFee` | write | result / revert |
| `fundVault` | payable | tx receipt |
| `withdraw` | write | result / revert |
| `requestFlashLoan` | write | uint256 |
| `executeFlashLoan` | write | result / revert |
| `failFlashLoan` | write | result / revert |
| `getLoan` | view | address borrower, uint256 amount, uint256 feeBps, uint256 timestamp, bool executed |

### Events

| Event | Signature |
|---|---|
| `OwnershipTransferred` | (address indexed previousOwner, address indexed newOwner) |
| `LoanRequested` | (uint256 indexed lid, address indexed borrower, uint256 amount, uint256 feeBps) |
| `LoanExecuted` | (uint256 indexed lid, address indexed borrower, uint256 amount, uint256 fee) |
| `LoanFailed` | (uint256 indexed lid, address indexed borrower, uint256 amount) |
| `VaultFunded` | (address indexed funder, uint256 amount) |
| `FeesWithdrawn` | (address indexed to, uint256 amount) |

## Network

| | |
|---|---|
| Chain | BOT Chain Mainnet (chainId `677`) |
| RPC | `https://rpc.botchain.ai` |
| Explorer | `https://scan.botchain.ai` |
| Native currency | BOT (18 decimals) |
| Testnet | BOT Chain Testnet (chainId `968`) - `https://rpc.bohr.life` |

## Frontend

- **Wallet connection** - [Reown/AppKit](https://reown.com) (Web3Modal v2, inline modal, `subscribeAccount` / `subscribeNetwork`)
- **Web3 library** - ethers.js v6 (`BrowserProvider`, `Contract`, `parseEther`)
- **Animation** - GSAP 3 + ScrollTrigger (`expo.out` entrances, `prefers-reduced-motion` fallback renders content instantly)
- **Zero build step** - single `index.html`, CDN imports via ESM import map; no bundler, no framework runtime
- **Accessibility** - auto-generated `aria-label`s on all binary and form controls, focus-visible styles, button busy states

## Run it locally

```bash
git clone https://github.com/Henoch4/flash-loan.git
cd flash-loan
# open the frontend directly (no build step)
start frontend/index.html   # Windows
# or serve it if your browser blocks file:// modules:
npx serve frontend
```

> **Note** — contract addresses: the UI reads its deploy target from the `CA` constant at the top of the inline script. Until the contract is deployed to mainnet 677, the demo runs against the deterministic sample data built into the page; after deployment, set `CA['677']` to the real address and every button goes live.