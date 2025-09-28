````markdown
# Klout Backend

This is the **backend for Klout**, powered by **Hardhat** and smart contracts.  
It contains all the contract code, deployment scripts, and configuration needed to run Klout’s wagering logic on Ethereum-compatible networks. The frontend (Next.js) interacts directly with these contracts using **ethers.js**.

---

## Features

- **Smart Contracts**
  - Core `WagerManager` contract handles wager creation, staking, and resolution.
  - Events (`WagerCreated`, `StakePlaced`, `WagerResolved`) allow the frontend to stay synced.

- **Development Environment**
  - Hardhat for local blockchain testing.
  - Gas reporting, contract verification, and coverage tools included.

- **Type-safe Contract Interaction**
  - TypeChain generates TypeScript bindings for safe contract calls.

- **Upgradeable and Secure**
  - Contracts follow OpenZeppelin standards.
  - Configured for testing on both local Hardhat node and public testnets.

---

## Tech Stack

- [Hardhat](https://hardhat.org/) – Ethereum development environment  
- [Solidity](https://soliditylang.org/) – Smart contract language  
- [ethers.js](https://docs.ethers.org/) – Contract interaction  
- [TypeChain](https://github.com/dethcrypto/TypeChain) – TypeScript bindings  
- [OpenZeppelin](https://openzeppelin.com/contracts/) – Secure, battle-tested contract libraries  

---

## Getting Started

### Prerequisites
- Node.js 18+  
- Yarn or npm  
- MetaMask (or any Web3 wallet)  
- An RPC provider (e.g. Infura, Alchemy, or local Hardhat node)

### Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/nap3-za/klout.git
   cd klout/backend
````

2. Install dependencies:

   ```bash
   npm install
   ```

3. Create a `.env` file with your settings:

   ```ini
   PRIVATE_KEY=your_wallet_private_key
   ALCHEMY_API_KEY=your_alchemy_key
   ETHERSCAN_API_KEY=your_etherscan_key
   ```

---

## ⚡ Usage

### Start a local Hardhat node

```bash
npx hardhat node
```

### Deploy contracts locally

```bash
npx hardhat run scripts/deploy.ts --network localhost
```

### Deploy to Sepolia testnet

```bash
npx hardhat run scripts/deploy.ts --network sepolia
```

### Verify contract on Etherscan

```bash
npx hardhat verify --network sepolia <DEPLOYED_CONTRACT_ADDRESS>
```

---

## Project Structure

```
backend/
├─ contracts/            # Solidity smart contracts
│  ├─ WagerManager.sol   # Core contract
│  └─ ...
├─ scripts/              # Deployment and interaction scripts
│  └─ deploy.ts
├─ test/                 # Unit tests for contracts
├─ typechain/            # Auto-generated TypeScript bindings
├─ hardhat.config.ts     # Hardhat config
├─ package.json
└─ .env.example
```

---

## Contracts

### WagerManager

* `createWager(topic, category, deadline)` – create a new wager.
* `stakeETH(wagerId, side)` – place a stake on YES or NO.
* `resolveWager(wagerId, outcome)` – resolves the wager.

**Events emitted:**

* `WagerCreated`
* `StakePlaced`
* `WagerResolved`

---

## Testing

Run unit tests:

```bash
npx hardhat test
```
