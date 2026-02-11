# mDL Data Flow

URLs below use `192.168.1.22:22080` for physical device testing. Use `localhost:22080` for browser-only. Controlled by `opencred_base_url` in application.yml.

## Flow

```mermaid
sequenceDiagram
    participant User
    participant Browser
    participant Rails as Login.gov (Rails)
    participant OpenCred
    participant Wallet as Mobile Wallet

    User->>Browser: Click "Verify with Apple Wallet"
    Browser->>Rails: GET /verify/mdl
    Rails->>Browser: Redirect to OpenCred /login
    Browser->>OpenCred: GET /login?client_id=...&redirect_uri=...
    OpenCred->>Browser: QR Code Page

    User->>Wallet: Scan QR Code
    Wallet->>OpenCred: GET authorization request JWT
    OpenCred->>Wallet: Signed JWT with presentation_definition
    Wallet->>User: Show consent screen
    User->>Wallet: Approve sharing
    Wallet->>OpenCred: POST VP Token + Presentation Submission
    OpenCred->>OpenCred: Verify VP signature
    OpenCred->>OpenCred: Verify VC signature
    OpenCred->>OpenCred: Extract claims, generate OIDC code

    Browser->>OpenCred: Poll exchange status
    OpenCred->>Browser: Exchange complete, redirect
    Browser->>Rails: GET /verify/mdl/callback?code=xxx&state=yyy
    Rails->>OpenCred: POST /token (exchange code)
    OpenCred->>Rails: id_token JWT with claims
    Rails->>Rails: Extract PII from id_token
    Rails->>Browser: Redirect to SSN screen
```

## Request/Response Data

### Rails -> OpenCred redirect

```
GET http://192.168.1.22:22080/login
  ?client_id=login-gov-mdl
  &redirect_uri=http://localhost:3000/verify/mdl/callback
  &response_type=code
  &scope=openid
  &state={random_csrf_token}
```

### QR code content (OID4VP)

```
openid4vp://?client_id=did:web:192.168.1.22:22080
            &request_uri=http://192.168.1.22:22080/workflows/login-gov-mdl-workflow
                         /exchanges/{exchange_id}/openid/client/authorization/request
```

### Auth request JWT (OpenCred -> Wallet)

```json
{
  "response_type": "vp_token",
  "response_mode": "direct_post",
  "client_id": "did:web:192.168.1.22:22080",
  "client_id_scheme": "did",
  "nonce": "{challenge}",
  "response_uri": "http://192.168.1.22:22080/workflows/.../authorization/response",
  "presentation_definition": {
    "id": "{uuid}",
    "input_descriptors": [{
      "id": "{uuid}",
      "constraints": {
        "fields": [{
          "path": ["$.vc.type", "$.type"],
          "filter": {"type": "string", "pattern": "VerifiableCredential"}
        }]
      },
      "format": {
        "jwt_vc_json": {"alg": ["ES256"]}
      }
    }]
  },
  "client_metadata": {
    "client_name": "OpenCred Verifier",
    "vp_formats": {
      "jwt_vp_json": {"alg": ["ES256"]}
    }
  }
}
```

### Wallet response

```
POST /workflows/.../authorization/response
Content-Type: application/x-www-form-urlencoded

vp_token={signed_jwt}&presentation_submission={json}
```

VP Token payload:
```json
{
  "iss": "did:jwk:{wallet_public_key}",
  "aud": "did:web:192.168.1.22:22080",
  "nonce": "{challenge}",
  "iat": 1735488000,
  "vp": {
    "@context": ["https://www.w3.org/2018/credentials/v1"],
    "type": ["VerifiablePresentation"],
    "verifiableCredential": ["{vc_jwt}"]
  }
}
```

VC JWT payload (inside VP):
```json
{
  "iss": "did:jwk:{issuer_key}",
  "sub": "did:jwk:{holder_key}",
  "iat": 1735488000,
  "exp": 1893456000,
  "vc": {
    "@context": ["https://www.w3.org/2018/credentials/v1"],
    "type": ["VerifiableCredential", "DriversLicenseCredential"],
    "issuer": "did:jwk:{issuer_key}",
    "issuanceDate": "2025-12-29T00:00:00.000Z",
    "credentialSubject": {
      "id": "did:jwk:{holder_key}",
      "given_name": "JANE",
      "family_name": "DOE",
      "birth_date": "1990-01-15",
      "document_number": "DL123456789",
      "issue_date": "2023-01-01",
      "expiry_date": "2028-01-01",
      "issuing_authority": "CA DMV",
      "issuing_jurisdiction": "US-CA",
      "resident_address": "123 MAIN ST",
      "resident_city": "SACRAMENTO",
      "resident_state": "CA",
      "resident_postal_code": "95814"
    }
  }
}
```

Presentation submission:
```json
{
  "id": "{uuid}",
  "definition_id": "{matches presentation_definition.id}",
  "descriptor_map": [{
    "id": "{matches input_descriptor.id}",
    "format": "jwt_vp_json",
    "path": "$",
    "path_nested": {
      "format": "jwt_vc_json",
      "path": "$.verifiableCredential[0]"
    }
  }]
}
```

### Token exchange (Rails -> OpenCred)

```
POST http://192.168.1.22:22080/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code={oidc_code}
&redirect_uri=http://localhost:3000/verify/mdl/callback
&client_id=login-gov-mdl
&client_secret=login-gov-secret-key
```

Response:
```json
{
  "access_token": "NONE",
  "token_type": "Bearer",
  "expires_in": 3600,
  "id_token": "{signed_jwt}"
}
```

### id_token claims

```json
{
  "iss": "http://192.168.1.22:22080",
  "aud": "login-gov-mdl",
  "sub": "did:jwk:{holder_key}",
  "iat": 1735488000,
  "exp": 1735491600,
  "given_name": "JANE",
  "family_name": "DOE",
  "birth_date": "1990-01-15",
  "document_number": "DL123456789",
  "issue_date": "2023-01-01",
  "expiry_date": "2028-01-01",
  "issuing_authority": "CA DMV",
  "issuing_jurisdiction": "US-CA",
  "resident_address": "123 MAIN ST",
  "resident_city": "SACRAMENTO",
  "resident_state": "CA",
  "resident_postal_code": "95814"
}
```

### PII mapping

| id_token | Rails | Example |
|----------|-------|---------|
| given_name | first_name | JANE |
| family_name | last_name | DOE |
| birth_date | dob | 1990-01-15 |
| document_number | state_id_number | DL123456789 |
| issue_date | state_id_issued | 2023-01-01 |
| expiry_date | state_id_expiration | 2028-01-01 |
| issuing_jurisdiction | state_id_jurisdiction | US-CA |
| resident_address | address1 | 123 MAIN ST |
| resident_city | city | SACRAMENTO |
| resident_state | state | CA |
| resident_postal_code | zipcode | 95814 |

## Architecture

```mermaid
flowchart TB
    subgraph "User Device"
        Browser[Browser]
        Wallet[Mobile Wallet App]
    end

    subgraph "Login.gov Rails App"
        Rails[Rails Server<br/>localhost:3000]
        MdlController[MdlController]
        Rails --- MdlController
    end

    subgraph "OpenCred Verifier"
        OpenCred[Node.js Server<br/>:22080<br/>Vue UI + API]
        MongoDB[(MongoDB)]
    end

    Browser -->|1. Start mDL flow| MdlController
    MdlController -->|2. Redirect to /login| OpenCred
    OpenCred -->|3. Show QR page| Browser
    Browser -.->|4. Scan QR| Wallet
    Wallet -->|5. Fetch auth request| OpenCred
    Wallet -->|6. Submit VP| OpenCred
    OpenCred -->|7. Store exchange| MongoDB
    OpenCred -->|8. Browser polls, redirect with code| MdlController
    MdlController -->|9. POST /token| OpenCred
    OpenCred -->|10. Return id_token| MdlController
    MdlController -->|11. Show SSN screen| Browser
```

## Signature chain

Demo wallet self-signs both VC and VP (same key). In prod, VC would be signed by issuer (CA DMV).

```mermaid
flowchart LR
    subgraph "Issuer (prod)"
        IssuerKey[Issuer Key<br/>CA DMV / P-256]
        VC[VC JWT]
        IssuerKey --> VC
    end

    subgraph "Wallet"
        WalletKey[Wallet Key<br/>P-256/ES256]
        VP[VP JWT<br/>contains VC]
        WalletKey --> VP
    end

    subgraph "OpenCred"
        VCVerify[Verify VC sig]
        VPVerify[Verify VP sig]
    end

    subgraph "OpenCred signs"
        OpenCredKey[OpenCred Key<br/>P-256/ES256]
        IDToken[id_token]
        OpenCredKey --> IDToken
    end

    VC --> VP
    VP --> VPVerify
    VC --> VCVerify
    VCVerify -->|Claims| IDToken
```

## Key files

| Component | File | What it does |
|-----------|------|--------------|
| Rails | `mdl_controller.rb` | Callback, token exchange |
| Rails | `mdl/show.html.erb` | Redirect to OpenCred |
| Rails | `application.yml` | OpenCred URL, creds |
| OpenCred | `combined.yaml` | RP config, claims |
| OpenCred | `native-workflow.js` | VP verification |
| OpenCred | `oidc.js` | Token endpoint |
| Wallet | `oid4vp.ts` | OID4VP handler |
| Wallet | `crypto.ts` | ES256 signing |
| Wallet | `credential.ts` | Test VC creation |
