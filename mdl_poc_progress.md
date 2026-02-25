## 2025-12-23 - mDL POC Progress

### What I Did

Set up OpenCred infrastructure from scratch. Goal was to get CA's OpenCred verifier running locally so we can test OID4VP flows without waiting for Apple Business Connect approval.

**Infrastructure setup:**
- Installed Docker Desktop
- Created `docker-compose.yaml` in opencred-local with OpenCred + MongoDB services
- Fixed MongoDB connection - container was trying to use `localhost` instead of Docker network hostname. Modified database.js to use `MONGODB_HOST` env var.
- Got OpenCred running on port 22080 (HTTP) and 22443 (HTTPS)

**OpenCred configuration:**
- Created `configs/combined.yaml` with Login.gov relying party config
- Generated ES256 signing key for authorization requests
- Configured native workflow: `login-gov-mdl-workflow`
- Enabled `didWeb.mainEnabled: true` so OpenCred serves its DID document

**Login.gov integration:**
- Added `opencred_*` settings to `application.yml`
- Existing mDL controller already had redirect logic to external verifier

### Decisions Made

**OpenCred over custom verifier** - Building OID4VP verification from scratch would take weeks. OpenCred is production-tested by CA DMV and handles all the credential format parsing, signature verification, and OIDC token exchange.

**Docker for local dev** - Easier than installing MongoDB and Node.js dependencies directly. Also matches how we'd deploy this in staging.

**HTTP for local testing** - HTTPS on 22443 had certificate issues ("Service Unavailable"). HTTP on localhost is still secure context for browsers. Physical device testing uses local network IP.

**Native workflow type** - OpenCred supports multiple workflow types. Native is the simplest - just OID4VP with direct_post response mode.

### Blockers / Open Questions

OpenCred is running but haven't tested with an actual wallet yet. Need to find a compatible mobile wallet app.

### Next Steps

1. Test with Sphereon wallet (open source, supposedly supports OID4VP)
2. Verify QR code generation works
3. Test full presentation flow

### Code References

**Docker compose (docker-compose.yaml):**
```yaml
services:
  opencred:
    image: nickreynolds/opencred:latest
    ports:
      - "22080:22080"
      - "22443:22443"
    environment:
      - MONGODB_HOST=mongodb
    depends_on:
      - mongodb
  mongodb:
    image: mongo:6
    ports:
      - "27017:27017"
```

**OpenCred RP config (combined.yaml):**
```yaml
relyingParties:
  - name: "Login.gov mDL POC"
    clientId: "login-gov-mdl"
    clientSecret: "login-gov-secret-key"
    redirectUri: "http://localhost:3000/verify/mdl/callback"
    workflow:
      type: native
      id: login-gov-mdl-workflow
```

---

## 2025-12-24 - mDL POC Progress

### What I Did

Spent the day testing third-party wallet apps. Every single one failed.

**Sphereon Wallet testing:**
- Downloaded iOS app, set up wallet
- Scanned OpenCred QR code
- Got "identifier not found" error initially - OpenCred wasn't serving its did:web document
- Fixed by adding `didWeb.mainEnabled: true` to config
- After fix: still failed. Different error in wallet logs about credential format.

**Lissi Wallet testing:**
- Downloaded iOS app, imported their demo PID credential
- Scanned QR code
- Got "access_denied" - "The End-User did not give consent"
- No credentials showed up to share. The wallet just couldn't find a matching credential.

**Walt.id Wallet testing:**
- Downloaded iOS app
- Scanned QR code
- Just showed a spinner forever. Never completed the exchange.

**Root cause investigation:**
- Dug into OpenCred's native-workflow.js code
- Found the issue: OpenCred only supports `jwt_vc_json` and `ldp_vc` formats
- Modern wallets (Sphereon, Lissi, etc.) use SD-JWT format
- These are fundamentally incompatible. Not a config fix - it's a format mismatch.

### Decisions Made

**No off-the-shelf wallet will work** - This is the critical finding. The industry has moved to SD-JWT (selective disclosure) but OpenCred was built for the older JWT-VC format. Every production wallet I could find uses SD-JWT.

Options considered:
1. Fork OpenCred and add SD-JWT support - too much work for POC
2. Find an obscure wallet that uses JWT-VC - couldn't find one
3. Build our own demo wallet - realistic option
4. Wait for Apple/Google Wallet direct API - blocked on Business Connect approval

### Blockers / Open Questions

**Critical blocker:** No compatible wallet exists.

Need to decide: build custom demo wallet or pivot approach entirely?

### Next Steps

1. Research what it would take to build a minimal React Native wallet
2. Check if any web-based CHAPI wallets work (they might use different formats)
3. Talk to team about whether custom wallet is acceptable for POC

### Code References

**OpenCred supported formats (native-workflow.js:279-288):**
```javascript
format: {
  jwt_vc_json: {
    alg: ['ES256']
  },
  ldp_vc: {
    proof_type: ['ecdsa-rdfc-2019']
  }
}
// SD-JWT not here - that's the problem
```

**OpenCred DID requirements (native-workflow.js:305-307):**
```javascript
subject_syntax_types_supported: ['did:jwk']
```

---

## 2025-12-26 - mDL POC Progress

### What I Did

Made the call to build a custom React Native demo wallet. Spent the day on research and spec writing.

**CHAPI testing (dead end):**
- Tried web-based CHAPI credential handler
- Got the demo verifier working but clicking "Open wallet" just showed "Did the app fail to launch?"
- CHAPI requires a registered credential handler, and we don't have one
- Abandoned this approach

**Custom wallet research:**
- Read through Sphereon's mobile-wallet source code
- Investigated OID4VC-TS library from OpenWallet Foundation
- Researched React Native crypto limitations (no WebCrypto in Hermes engine)
- Found solutions: `@noble/curves` for P-256 signing, `expo-secure-store` for key storage

**Created implementation spec:**
- Wrote `demo_wallet_prompt.txt` - full spec for building the wallet
- Covers OID4VP protocol flow, project structure, JWT formats, all the gotchas
- Should be enough to build from

**Prepared Q&A for implementation:**
- Created `question.txt` with implementation questions
- Created `answers.txt` with resolved decisions

### Decisions Made

**Build custom React Native wallet** - It's the only way to demonstrate the flow. Third-party wallets won't work due to format mismatch. This is a demo, not production.

**Expo SDK 51** - SDK 52 removed expo-barcode-scanner and requires migration. SDK 51 is stable and Sphereon uses it.

**Hybrid implementation** - Build OID4VP protocol handling manually but use proven crypto libraries (`@noble/curves`, `jose` where possible). Don't reinvent crypto.

**Self-signed test credentials** - OpenCred's `trustedCredentialIssuers` is empty, so it accepts any issuer. Wallet can self-sign a test mDL credential for demo purposes.

**iOS physical device primary target** - Login.gov has strong iOS user base. Physical device testing is more realistic than simulator.

**HTTP for local testing** - Use computer's local IP (192.168.x.x) on port 22080. HTTPS has cert issues locally.

### Blockers / Open Questions

None for now. Clear path forward with custom wallet.

Long-term question: what's the production wallet strategy? Options:
- Contribute SD-JWT support to OpenCred
- Use Apple/Google direct APIs (requires Business Connect)
- Find a different verifier that supports SD-JWT

### Next Steps

1. Create demo-mdl-wallet project at `/Users/mwarren/IdeaProjects/demo-mdl-wallet/`
2. Set up Expo with SDK 51
3. Implement crypto service with P-256 key generation
4. Implement OID4VP protocol handler
5. Build 4 screens: Home, Scanner, Consent, Result
6. Test end-to-end with OpenCred

### Code References

**Wallet project structure:**
```
demo-mdl-wallet/
├── App.tsx
├── src/
│   ├── screens/
│   │   ├── HomeScreen.tsx
│   │   ├── ScannerScreen.tsx
│   │   ├── ConsentScreen.tsx
│   │   └── ResultScreen.tsx
│   ├── services/
│   │   ├── crypto.ts
│   │   ├── oid4vp.ts
│   │   └── credential.ts
│   └── constants/
│       └── testCredential.ts
```

**Test credential type:**
```json
{
  "type": ["VerifiableCredential", "DriversLicenseCredential"]
}
```

**Expected VP response format:**
```
POST /authorization/response
Content-Type: application/x-www-form-urlencoded

vp_token=<signed-jwt>&presentation_submission=<json>
```

---

## 2025-12-29 - mDL POC Progress

### What I Did

Got the demo React Native wallet app successfully submitting Verifiable Presentations to OpenCred. This was a multi-session debugging effort that finally clicked today.

**Files touched:**
- `demo-mdl-wallet/src/services/oid4vp.ts` - fixed presentation_submission path
- `demo-mdl-wallet/src/services/crypto.ts` - signature fixes from previous session
- `identity-idp/config/application.yml` - fixed opencred_base_url
- `opencred-local/configs/combined.yaml` - verified config is correct

**The signature verification saga (resolved):**
The wallet was getting `invalid_signature: no matching public key found` errors. Root cause was prehash incompatibility between `@noble/curves` and `did-jwt-vc`. Noble's `p256.sign()` with default `prehash: true` produces signatures that jose/did-jwt-vc can't verify.

Fix: manually hash with SHA-256 and use `prehash: false`:
```typescript
const messageHash = sha256(messageBytes);
const signatureResult = p256.sign(messageHash, privateKeyBytes, { prehash: false });
```

**The "VC not found in presentation" error (resolved):**
After fixing signatures, got a new error. OpenCred's native-workflow.js queries the verified presentation using jsonpath and expects `vc.proof.jwt` structure.

The wallet was sending `path_nested.path: '$.vp.verifiableCredential[0]'` but `did-jwt-vc`'s `verifyPresentation` returns the VP content directly - it's not wrapped in another `vp` object.

Fix: changed path from `$.vp.verifiableCredential[0]` to `$.verifiableCredential[0]`

**Config mismatch (resolved):**
Rails was configured to call `http://localhost:22080/token` but OpenCred runs on `192.168.1.22:22080`. Updated `opencred_base_url` in application.yml.

### Decisions Made

**Using `@noble/curves` instead of SubtleCrypto:** React Native doesn't have native WebCrypto for ECDSA P-256 signing. Noble works but has quirks with the prehash behavior that differ from jose/did-jwt-vc expectations.

**Self-signed test credentials:** The wallet creates self-signed VCs with did:jwk issuer. Good enough for POC since OpenCred's `trustedCredentialIssuers` is empty (accepts any issuer). Real implementation would need actual CA-issued mDL credentials.

**Expo SecureStore for key storage:** Keys persist in device keychain. Using versioned storage keys (`wallet_private_key_v7`) to handle schema changes during development.

### Blockers / Open Questions

**Current status:** Wallet submits VP, gets 204 success from OpenCred. Browser redirects to Rails callback with code. But Rails callback shows "An error occurred during verification" - need to check server logs to see if it's the token exchange or id_token parsing.

Possible issues:
1. Token exchange endpoint connectivity (should be fixed now with correct base URL)
2. Claims extraction from VC - OpenCred extracts from `credentialSubject` using jsonpath, need to verify paths match
3. JWT decode in Rails - might fail if id_token structure is unexpected

### Next Steps

1. Test the full flow now that Rails is restarted with correct config
2. Check Rails server logs if callback still fails - look for `[MdlController]` log lines
3. If token exchange works, verify claims are mapping correctly from VC to id_token to Rails PII struct
4. Once flow works end-to-end, clean up debug logging in wallet app

### Code References

**Wallet signing (crypto.ts:118-145):**
```typescript
export function signES256(data: string, privateKeyJwk: JsonWebKey): string {
  const privateKeyBytes = base64UrlDecode(privateKeyJwk.d);
  const messageBytes = new TextEncoder().encode(data);
  const messageHash = sha256(messageBytes);
  const signatureResult = p256.sign(messageHash, privateKeyBytes, { prehash: false });
  // Handle both Uint8Array and Signature object returns
  let signatureBytes: Uint8Array;
  if (signatureResult instanceof Uint8Array) {
    signatureBytes = signatureResult;
  } else if (typeof signatureResult.toCompactRawBytes === 'function') {
    signatureBytes = signatureResult.toCompactRawBytes();
  }
  return base64UrlEncode(signatureBytes);
}
```

**Presentation submission path (oid4vp.ts:117-120):**
```typescript
path_nested: {
  format: 'jwt_vc_json',
  path: '$.verifiableCredential[0]',  // NOT $.vp.verifiableCredential[0]
},
```

**OpenCred VC extraction (native-workflow.js:107-111):**
```javascript
const vc = jp.query(
  vpResult.verifiablePresentation,
  submitted.path_nested.path
)[0];
if(vc && vc.proof && vc.proof.jwt) {
  // verify the inner JWT
}
```

**Rails token exchange (mdl_controller.rb:204-227):**
Uses Faraday to POST to `{opencred_base_url}/token` with authorization_code grant.

---

## 2025-12-29 (Session 2) - mDL POC Progress

### What I Did

Documentation session. Reviewed current state of the integration to capture where things stand.

**Files in play:**
- `mdl_controller.rb` - callback at `:17-64`, token exchange at `:204-227`, PII extraction at `:230-263`
- `mdl/show.html.erb` - JS redirects to OpenCred `/login` with OIDC params
- `mdl_request_builder.rb` - legacy, builds ISO 18013-7 DeviceRequest (not used in OIDC flow)
- `mdl_response_parser.rb` - legacy, parses CBOR DeviceResponse (not used in OIDC flow)

### Decisions Made

**OpenCred OIDC over direct wallet API** - Direct W3C Digital Credentials API requires Apple Business Connect cert, domain verification, Safari 26+/iOS 26+, HPKE decryption. OpenCred abstracts all that behind standard OIDC.

**Kept legacy request_credentials/verify endpoints** - Might be useful for testing direct wallet integration later if we want to bypass OpenCred.

**Mock fallback preserved** - Controller falls back to hardcoded mock PII if parsing fails (unless `mdl_strict_validation: true`). Useful for demos.

**JWT not verified** - `extract_pii_from_id_token` decodes without signature verification. Fine for POC.

### Blockers / Open Questions

1. **Where did the flow break?** Previous session got wallet submitting VP successfully (204 from OpenCred) but Rails callback showed generic error. Need to check if it's token exchange or id_token parsing.

2. **Claims mapping** - OpenCred extracts from `credentialSubject` using jsonpath. Need to verify the paths in `combined.yaml` actually match what the wallet sends.

3. **Feature flags** - `mdl_verification_enabled`, `mdl_strict_validation`, `opencred_*` configs all need to be set in `application.yml`.

### Next Steps

- [ ] Run Rails with logs visible, hit the full flow, check `[MdlController]` output
- [ ] Verify token exchange actually succeeds (check response from `/token`)
- [ ] Verify id_token contains expected claims
- [ ] If flow works, test that PII shows up on SSN screen

### Code References

**Config needed in application.yml:**
```yaml
mdl_verification_enabled: true
mdl_strict_validation: false
opencred_base_url: http://192.168.1.22:22080
opencred_client_id: login-gov-mdl
opencred_client_secret: login-gov-secret-key
```

**OpenCred relying party config (combined.yaml:29-37):**
```yaml
- name: "Login.gov mDL POC"
  clientId: "login-gov-mdl"
  clientSecret: "login-gov-secret-key"
  redirectUri: "http://localhost:3000/verify/mdl/callback"
```
