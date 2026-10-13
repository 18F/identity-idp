# ADR 0001 Flows: Account-Preserving MFA Recovery

Companion diagrams for
[ADR 0001: Account-Preserving MFA Recovery](./0001-account-preserving-mfa-recovery.md). The ADR is
authoritative; these diagrams illustrate it. Component names prefixed with `Proposed` do not exist
yet and are illustrative, not final class names.

## 1. Routing: legacy vs. account-preserving recovery

Routing happens only after successful password authentication, when the user reports they cannot
access any MFA method.

```mermaid
flowchart TD
    A[User submits email + password] --> B{Password valid?}
    B -- No --> A
    B -- Yes --> C{Active request<br/>in either flow?}
    C -- Legacy request --> L2[Legacy pending page]
    C -- Recovery request --> R2[Recovery pending page]
    C -- None --> D[MFA challenge]
    D -- Uses MFA --> OK[Normal AAL2 session]
    D -- Can't access MFA --> E{Feature Flag on?}
    E -- No --> LEG[Legacy destructive account reset]
    E -- Yes --> F{Identity-proofed<br/>active/pending profile?}
    F -- Yes --> LEG
    F -- No --> G{Other eligibility checks<br/>fraud, verified email, etc.}
    G -- Fail --> H[Legacy path or explicit<br/>unavailable outcome per policy]
    G -- Pass --> I{Persisted A/B bucket<br/>by user UUID}
    I -- Control --> LEG
    I -- Treatment --> NEW[Account-preserving MFA recovery]

    LEG --> LP[Persist flow_variant = legacy]
    NEW --> NP[Persist flow_variant = account_preserving]

    classDef legacy fill:#fde2e2,stroke:#b00;
    classDef recovery fill:#e2f5e2,stroke:#080;
    class LEG,LP,L2 legacy;
    class NEW,NP,R2 recovery;
```

Key rule: once a request is created, its `flow_variant` is fixed. Flag or bucket changes never
move an in-flight request to the other flow.

## 2. End-to-end sequence (programmatic)

```mermaid
sequenceDiagram
    autonumber
    actor U as User / Browser
    participant S as Users::SessionsController
    participant RC as ProposedRecovery::RequestController
    participant P as ProposedRecoveryPolicy<br/>(eligibility + authorization)
    participant DB as Recovery record (DB)
    participant J as ProposedGrantRecoveryJob
    participant M as Mailers / notifications
    participant LC as ProposedRecovery::LinkController
    participant PW as ProposedRecovery::PasswordController
    participant MFA as Existing MFA setup controllers
    participant CS as ProposedRecovery::Complete service
    participant A as Analytics + user Events

    Note over U,S: Phase 1: request (user is password-authenticated, not MFA-authenticated)
    U->>S: Sign in with password
    S-->>U: MFA challenge
    U->>RC: "I can't access my MFA"
    RC->>P: eligible?(user) + bucket + kill switch
    P-->>RC: account_preserving
    RC->>A: options visited / eligibility evaluated
    U->>RC: Confirm request
    RC->>RC: Rate limit (per user)
    RC->>DB: LOCK user, cancel/reject other active request,<br/>INSERT state=waiting, flow_variant, requested_at
    RC->>M: "Recovery requested" notice to all addresses<br/>(includes cancel instructions)
    RC->>A: Account Recovery: request
    RC-->>U: Pending page (sign out)

    Note over U,J: Phase 2: wait period (old MFA still active)
    alt User signs in with old MFA during wait
        U->>S: Normal MFA success
        S->>DB: state=cancelled (reason: mfa_used)
        S->>A: Account Recovery: cancelled
    else User cancels
        U->>RC: Cancel (authenticated page or cancel link)
        RC->>DB: state=cancelled
        RC->>M: Cancellation notice
    end

    J->>DB: SELECT waiting requests past wait period
    J->>DB: generate token, store digest only,<br/>state=granted, granted_at, expires_at (<=24h)
    J->>M: Magic-link email (raw token only in link)
    J->>A: Account Recovery: granted

    Note over U,LC: Phase 3: redeem link + fresh password
    U->>LC: GET link (token)
    LC->>LC: Throttle validation attempts
    LC->>DB: LOCK, compare digest, check state=granted,<br/>not expired, flow_variant matches
    alt Invalid / expired / replayed
        LC->>A: link validation (success: false, failure_reason)
        LC-->>U: Safe error page
    else Valid
        LC->>DB: state=link_verified
        LC->>A: link validation (success: true)
        LC-->>U: Re-enter password
        U->>PW: Password
        PW->>PW: Throttle password attempts
        alt Wrong password
            PW->>A: password verification (success: false)
        else Correct
            PW->>DB: state=password_verified,<br/>INSERT suspension rows for old MFA,<br/>ForgetAllBrowsers (configs untouched)
            PW->>P: issue recovery-limited authorization<br/>(server-side, bound to request id)
            PW->>A: password verification (success: true)
            PW->>M: "Recovery evidence accepted" notice
        end
    end

    Note over U,MFA: Phase 4: enroll replacement MFA (recovery-limited authorization)
    U->>MFA: Choose method (allowed list)
    MFA->>P: authorized_for_recovery_setup?
    P-->>MFA: yes (scoped to setup routes only)
    MFA->>DB: state=replacement_mfa_pending<br/>(nothing persisted until final verification)
    MFA->>A: MFA setup started / submitted
    U->>MFA: Verify new method (OTP, WebAuthn, etc.)

    Note over CS,DB: Phase 5: atomic completion
    MFA->>CS: complete!(request, verified_setup_params)
    CS->>DB: BEGIN, LOCK request + user, re-check state/expiry
    CS->>DB: destroy suspended old configs via existing delete paths,<br/>suspension rows revoked_at = now
    CS->>DB: create replacement config via existing setup form
    CS->>DB: consume token, state=completed
    CS->>DB: invalidate other recovery authorizations,<br/>revoke remember-device
    CS->>DB: COMMIT
    CS->>A: old MFA revoked / completed, user Events
    CS->>M: MFA added + old MFA removed + completion notice<br/>(with "this wasn't me" instructions)
    CS-->>U: Sign out recovery authorization, redirect to sign-in

    Note over U,S: Phase 6: fresh normal sign-in
    U->>S: Password + new MFA
    S-->>U: Normal AAL2 session (primary success metric)
```

## 3. Recovery request state machine

```mermaid
stateDiagram-v2
    [*] --> requested: password-authenticated user\nselects recovery (treatment, eligible)
    requested --> waiting: record persisted,\nnotice sent
    waiting --> granted: job after wait period;\ntoken digest stored, link emailed
    granted --> link_verified: valid token\n(atomic check)
    link_verified --> password_verified: fresh password correct;\nold MFA suspended
    password_verified --> replacement_mfa_pending: setup started\n(recovery-limited auth)
    replacement_mfa_pending --> completed: new MFA verified;\natomic replace + revoke

    waiting --> cancelled: user cancel / old MFA used /\nbecame IDV
    granted --> cancelled: user cancel / old MFA used /\nbecame IDV
    link_verified --> cancelled: user cancel / became IDV
    password_verified --> cancelled: user cancel / became IDV
    replacement_mfa_pending --> cancelled: user cancel / became IDV

    granted --> expired: token TTL elapsed
    link_verified --> expired: recovery TTL elapsed
    password_verified --> expired: recovery TTL elapsed
    replacement_mfa_pending --> expired: recovery TTL elapsed

    waiting --> superseded: new request / legacy request
    granted --> superseded: new request / legacy request
    link_verified --> superseded: new request
    password_verified --> superseded: new request
    replacement_mfa_pending --> superseded: new request

    completed --> [*]
    cancelled --> [*]
    expired --> [*]
    superseded --> [*]
```

Terminal states (`completed`, `cancelled`, `expired`, `superseded`) never return to an active
state. Each transition and its side effects run under a row lock or equivalent atomic update.

## 4. Old MFA lifecycle

```mermaid
stateDiagram-v2
    [*] --> active
    active --> active: recovery requested / waiting / granted\n(still usable; using it cancels recovery)
    active --> pending_revocation: link + fresh password verified\n(suspended from sign-in)
    pending_revocation --> revoked: completion transaction\n(same commit as new MFA activation)
    pending_revocation --> pending_revocation: recovery expired/cancelled\n(NOT auto-restored; retry or new request)
    revoked --> [*]
```

The replacement method is never persisted as an inactive configuration. It is created inside the
completion transaction, after the old rows are destroyed, so a partially configured method is
never active and the unique indexes cannot collide. "Suspended" is not a column on the
configuration tables; it is a row in the recovery-owned suspension ledger. See the ADR section
[Implementing the suspended (inactive) state](./0001-account-preserving-mfa-recovery.md#implementing-the-suspended-inactive-state).

```mermaid
flowchart LR
    subgraph Ledger["account_recovery_mfa_suspensions (new)"]
        S[suspension row<br/>type + configuration_id<br/>suspended_at / revoked_at / released_at]
    end
    CFG[(Existing config tables<br/>unchanged schema)]
    S -. references, no FK .-> CFG

    Q{AccountRecovery::MfaSuspension<br/>suspended?}
    Q -->|checked by| E1[Post-password routing]
    Q -->|checked by| E2[2FA verification controllers<br/>+ handle_valid_verification guard]
    Q -->|checked by| E3["/otp/send and resend"]
    Q -->|checked by| E4[Passwordless PIV/CAC login]
    Q -->|checked by| E5[MFA option presenters]
    RD[ForgetAllBrowsers at suspension] -->|blocks| E6[Remember-device bypass]
    S --> Q
```

## 5. Authorization boundaries

```mermaid
flowchart LR
    subgraph Auth["Authorization level"]
        PWD[Password-only<br/>pre-MFA]
        REC[Recovery-limited<br/>authorization]
        FULL[Normal AAL2 session]
    end

    PWD -->|allowed| R1[Recovery options, request, pending, cancel]
    PWD -->|allowed| R1b[Legacy account reset routes]
    PWD -.->|denied| X1[Account pages, SP handoff, MFA setup]

    REC -->|allowed| R2[Replacement MFA setup + verification<br/>for allowed methods]
    REC -->|allowed| R3[Cancel recovery]
    REC -.->|denied| X2[Account pages, email/password change,<br/>SP assertions, remember-device,<br/>deleting MFA outside completion]

    FULL -->|only after| R4[Fresh sign-in with new MFA]
```

`MfaSetupConcern#confirm_user_authenticated_for_2fa_setup` is not weakened. Instead it gains one
explicit, separately tested branch: allow setup when `ProposedRecoveryPolicy` confirms a valid
recovery-limited authorization bound to an active request in `password_verified` or
`replacement_mfa_pending`.

## 6. Telemetry funnel and comparison

```mermaid
flowchart TD
    subgraph Treatment["Treatment: account-preserving"]
        T1[options visited] --> T2[eligibility evaluated]
        T2 --> T3[request]
        T3 --> T4[granted]
        T4 --> T5[link validation success]
        T5 --> T6[password verification success]
        T6 --> T7[MFA setup started]
        T7 --> T8[MFA setup submitted success]
        T8 --> T9[old MFA revoked]
        T9 --> T10[completed]
        T10 --> T11[Next sign-in with replacement MFA]
    end

    subgraph Control["Control: legacy deletion (existing events)"]
        C1[Account deletion and reset:<br/>recovery options visited] --> C2[request]
        C2 --> C3[granted / email sent]
        C3 --> C4[delete account]
        C4 --> C5[New account created + MFA set up]
    end

    T3 -.-> X[cancelled / expired]
    T4 -.-> X
    T6 -.-> X
    C2 -.-> Y[cancelled]
```

All events carry `flow_variant` and the persisted A/B bucket via existing analytics A/B
integration. Primary metric: distinct eligible users reaching **T11** ÷ distinct eligible users
reaching **T3**. Control is compared on users who regain a working account (C5) ÷ requests (C2),
noting that control loses account continuity by design.

## 7. IDV users

```mermaid
flowchart TD
    A[Can't access MFA] --> B{Active or pending<br/>identity-proofed profile?}
    B -- Yes --> L[Existing legacy path<br/>regardless of flag or bucket;<br/>excluded from experiment analysis]
    B -- No --> N[Continue IAL1 routing, section 1]
    N --> M{Becomes IDV<br/>mid-recovery?}
    M -- Yes --> C[Cancel: ineligible_idv_profile<br/>no MFA mutation; offer legacy path]
    M -- No --> R[Continue recovery]
```
