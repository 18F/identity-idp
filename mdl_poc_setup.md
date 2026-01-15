# mDL POC Setup

## What this is

POC for mDL verification using OpenCred as the OID4VP verifier. User selects mDL option, scans QR with wallet, PII flows back to Rails via OIDC.

## Prerequisites

- Docker Desktop running
- OpenCred repo cloned at `../opencred-local`
- Physical iOS device on same network (for wallet testing)

## Start OpenCred

```bash
cd ../opencred-local
docker-compose up
```

Runs on `localhost:22080`. For physical device testing, use your machine's local IP (e.g. `192.168.1.22:22080`).

## Config

In `config/application.yml` under development:

```yaml
mdl_verification_enabled: true
opencred_base_url: 'http://localhost:22080'
opencred_client_id: 'login-gov-mdl'
opencred_client_secret: 'login-gov-secret-key'
```

For physical device testing, change `opencred_base_url` to your local IP.

## Start Rails

```bash
RAILS_MAX_THREADS=3 make run
```

## Test the flow

1. Go through IDV flow until "How would you like to verify?"
2. Select "Mobile driver's license"
3. Click the Apple Wallet button
4. Scan QR with demo wallet app (or OpenCred shows mock success after timeout)
5. Should redirect to SSN screen with PII populated

## Demo wallet

The demo wallet app is at `../demo-mdl-wallet`. See that repo for setup.

```bash
cd ../demo-mdl-wallet
npx expo start
```

Scan the Expo QR with your phone to run the wallet.

## Architecture

See `dataflow.md` for the full data flow and component diagram.
