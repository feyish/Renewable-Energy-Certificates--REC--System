# Renewable Energy Certificates (REC) System

A comprehensive blockchain-based system for managing renewable energy certificates built on the Stacks blockchain using Clarity smart contracts.

## Overview

This system provides a complete solution for tracking, trading, and retiring renewable energy certificates. It ensures transparency, prevents double-counting, and enables efficient trading of clean energy credits.

## System Architecture

### Core Contracts

1. **Generation Verification Contract** (`generation-verification.clar`)
    - Validates clean energy production amounts
    - Records generation data from certified sources
    - Maintains producer registry and verification status

2. **Certificate Issuance Contract** (`certificate-issuance.clar`)
    - Creates tradeable renewable energy credits
    - Links certificates to verified generation data
    - Manages certificate metadata and ownership

3. **Trading Marketplace Contract** (`trading-marketplace.clar`)
    - Facilitates REC buying and selling
    - Manages order books and price discovery
    - Handles escrow and settlement

4. **Retirement Tracking Contract** (`retirement-tracking.clar`)
    - Records certificate usage for compliance
    - Prevents double-counting of retired certificates
    - Maintains retirement registry

5. **Audit Verification Contract** (`audit-verification.clar`)
    - Validates environmental claims and benefits
    - Provides third-party verification services
    - Maintains audit trails and compliance records

## Key Features

- **Transparent Tracking**: Complete lifecycle visibility from generation to retirement
- **Fraud Prevention**: Cryptographic verification prevents double-counting
- **Efficient Trading**: Automated marketplace with price discovery
- **Compliance Ready**: Built-in audit trails and reporting
- **Scalable Design**: Modular architecture supports various energy sources

## Data Flow

1. Energy producers register and submit generation data
2. Verified generation triggers certificate issuance
3. Certificates can be traded on the marketplace
4. End users retire certificates for compliance
5. All actions are audited and verified

## Getting Started

### Prerequisites

- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for deployment

### Installation

\`\`\`bash
git clone <repository-url>
cd renewable-energy-certificates
npm install
clarinet check
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Usage Examples

### Register as Energy Producer

\`\`\`clarity
(contract-call? .generation-verification register-producer
"Solar Farm Alpha"
"solar"
u1000000)
\`\`\`

### Submit Generation Data

\`\`\`clarity
(contract-call? .generation-verification submit-generation
u500000
u1640995200
"verification-hash")
\`\`\`

### Issue Certificate

\`\`\`clarity
(contract-call? .certificate-issuance issue-certificate
u1
u500000
"solar")
\`\`\`

### Create Trading Order

\`\`\`clarity
(contract-call? .trading-marketplace create-sell-order
u1
u100)
\`\`\`

### Retire Certificate

\`\`\`clarity
(contract-call? .retirement-tracking retire-certificate
u1
"compliance-2024")
\`\`\`

## Contract Specifications

### Error Codes

- `ERR-NOT-AUTHORIZED` (u100): Caller lacks required permissions
- `ERR-INVALID-INPUT` (u101): Invalid input parameters
- `ERR-NOT-FOUND` (u102): Requested resource not found
- `ERR-ALREADY-EXISTS` (u103): Resource already exists
- `ERR-INSUFFICIENT-BALANCE` (u104): Insufficient token balance
- `ERR-INVALID-STATE` (u105): Invalid contract state for operation

### Data Types

- **Producer**: Energy generation facility information
- **Generation**: Verified energy production record
- **Certificate**: Tradeable renewable energy credit
- **Order**: Marketplace buy/sell order
- **Retirement**: Certificate retirement record

## Security Considerations

- All critical operations require proper authorization
- Input validation prevents malicious data
- State transitions are atomic and consistent
- Audit trails provide complete transparency

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details
