# ARSXEngine 💸🇦🇷

## Overview

**ARSXEngine** is a decentralized stablecoin engine designed to issue and manage **ARSX**, a crypto-collateralized stablecoin pegged to the Argentine Peso (ARS). Inspired by MakerDAO's DAI model and Patrick Collins' DSCEngine, this system aims to maintain a 1 ARSX = 1 ARS peg, while remaining overcollateralized and decentralized.

The protocol supports:

- **Overcollateralized minting** of ARSX.
- **Redemption and liquidation** mechanisms to keep the system solvent.
- Flexible governance parameters for risk management.
- Integration with custom ARS/USD price oracles (Chainlink Functions-based).

---

## Components

### Contracts

#### ARSXEngine.sol

- **Collateral management**: Deposit, withdraw, mint ARSX, and repay debt.
- **Liquidations**: Handles undercollateralized positions with a bonus for liquidators.
- **Health factor enforcement**: Ensures user positions remain healthy.
- **Governance functions**: Adjust liquidation thresholds, bonuses, and oracle freshness.

#### ARSXStableCoin.sol

- Minimal ERC20 implementation with minting and burning controlled by ARSXEngine.
- Provides the ARSX token used for debt representation and settlements.

---

## Features

✅ Overcollateralized ARS-pegged stablecoin.  
✅ Uses external crypto collateral (e.g., ETH or other ERC20 tokens).  
✅ Supports partial liquidations with customizable bonus.  
✅ Oracle freshness control to avoid outdated prices.  
✅ Owner-controlled parameters (liquidation thresholds and bonuses).  
✅ Inspired by DAI, but designed with no governance tokens, fees, or surplus mechanisms.

---

## Foundry Tests 🧪

The repo includes a robust suite of tests using [Foundry](https://book.getfoundry.sh/) to ensure core mechanisms work as expected.

**Test coverage:**

- Collateral deposits and withdrawals.
- Minting and burning ARSX.
- Combined deposit & mint workflows.
- Collateral redemption for ARSX.
- Health factor checks.
- Liquidations with price drops.

---

## Audits 🔒

This repository includes two AI-based audits (from GPT-4o) covering:

- Security vulnerabilities.
- Gas optimizations.
- Best practice improvements.
- Code readability and maintainability suggestions.

---

## Documentation

- **Health factor**: Must remain ≥ 1.0 to avoid liquidations. Calculated using collateral value vs ARSX debt.
- **Liquidation bonus**: Default 10%, configurable via governance.
- **Liquidation threshold**: Default 50%, requires 200% collateralization.

---

## Usage

### Example flow

1️⃣ User deposits collateral (e.g., ETH).  
2️⃣ User mints ARSX up to the allowed limit (based on health factor).  
3️⃣ User can repay ARSX to unlock collateral.  
4️⃣ If health factor drops below 1, position is eligible for liquidation.

---

## Governance

- Owner (initial deployer) can adjust risk parameters:
  - `liquidationThreshold`
  - `liquidationBonus`
  - Oracle staleness parameters

---

## License

[MIT](LICENSE)

---

## Author

Rodrigo Garcia Kosinski

---

## Acknowledgments

- Patrick Collins (DSCEngine inspiration).
- MakerDAO and DAI design principles.
- Chainlink community and oracle tooling.

---

### 💬 Questions or ideas?

Open an issue or reach out! Contributions and audits are welcome. 🚀

