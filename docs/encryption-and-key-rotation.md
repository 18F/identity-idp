# login.gov PII Encryption

## Overview

`login.gov` is a service that provides single-sign-on capability to
users of US government websites. It is developed jointly by 18F and USDS.
Its goals include:

* simplifying online interactions with the US government, by
  reducing the number of usernames and passwords people need to remember;
* improving security, by reducing the number of passwords people need to memorize,
  and implementing multi-factor authentication;
* helping government online services avoid the need to develop and host their
  own authentication systems, by serving as a federated identity-as-a-service.

Because the long term vision of `login.gov` is ubiquitous use across
government, it is expected that someday nearly all Americans will have a
`login.gov` account. This means that securely storing sensitive personally identifiable
information (PII), such as Social Security Numbers (SSN) or passwords, is critical.

This document outlines the technical measures `login.gov` has implemented to
meet its responsibility for the secure storage of this information.

## Design considerations

Almost everyone will agree that sensitive information should be encrypted.
However, merely saying "data is encrypted" is insufficient in real-world
systems; instead we have to be concerned with implementation specifics,
including key management.

Many systems encrypt data at rest with a single online key.
Unfortunately, many attacks which compromise the
ciphertext will also compromise the key, so these designs provide limited
protection.

We categorize two kinds of PII because of how they are used: server-accessible and private.
Server-accessible PII consists of email address and phone number, both used for multi-factor authentication.
Private PII includes everything else a verified user might register with us for asserting to relying parties:
full name, address, date of birth, and SSN.

Therefore, we have adopted the following design goals:

* Encryption should rely on a multi-factor model, just like authentication does.
* Long term private PII storage should be encrypted under a key derived from the user's
  password.
* Short term (session length) sensitive PII storage may be encrypted
  under a key controlled exclusively by the server.
* Private PII only needs to be available during the user session. Offline/background
  access is not necessary. The exception is server-accessible PII (email and phone).
* Duplicate SSNs should not be allowed for separate accounts.
* Forgetting your password should not necessarily result in all PII being lost.
* The ciphertexts should be able to be migrated between cloud providers including
  HSM providers.

## Implementation

To address all these design goals we have implemented a multi-factor
encryption model.

When a user first creates an account, we create an scrypt digest of the user's
password, which we then use as a key to AES encrypt the private PII.
That ciphertext is then encrypted with Amazon KMS.

This model means the user's password and access to KMS is required to decrypt data.
KMS encryption activities can be monitored and audited to detect anomalous activity.
Encrypting with the user's password means that a ciphertext that has been decrypted by KMS
still requires brute forcing the user's password, which is expected to take large amount
of time due to the scrypt step.

Additionally, having KMS as the last step for encryption means that the Login.gov
team can move between instances of KMS or potentially abandon KMS in favor of a different tool.
This can be done by decrypting ciphertexts with the existing KMS instance and then
re-encrypting them with the replacement before writing back to the database.

Since the user's password is an integral part of this multi-factor
model, if the user forgets their password, the PII may not be recovered.
To mitigate that loss, we repeat the process above using the user recovery
code, a randomly generated 128-bit string the user is given when they create
their account. The backup code can be used once as a replacement for their
second authentication factor (e.g. if they lose their mobile phone). It also functions
as a backup password for encrypted PII.

On login, the decryption process is applied, and the PII is re-encrypted
with the same multi-factor model, using a server-controlled key in place of the user
password digest so that the PII can be accessed by the server for the life of the session.

When PII needs to be accessed (e.g. to show a user their SSN, or to assert to a
government relying party) the ciphertext is
read from the session, decrypted using the server-controlled key, and the
particular data elements needed are extracted.

When sessions expire, the ciphertext they contain is deleted.

When a user loses their password and requests a reset, if the user has
encrypted private PII stored with us, they are also prompted for their backup code.
The backup code acts as a backup password. Their PII can be decrypted,
a new backup code generated, and the PII re-encrypted. If the user loses their
backup code and their password, they will need to go through the proofing process
again after they reset their password.

In order to facilitate fast lookups of existing SSNs and help prevent
fraud attempts, a HMAC fingerprint is taken of each SSN and stored outside
the encrypted PII payload. The fingerprint is a one-way hash of the SSN, combined
with a server-controlled secret.

## Cryptographic primitives

The following cryptographic primitives are used:

- Symmetric keys: 256-bit AES keys
- Symmetric encryption: AES-256 in GCM mode, with 12-byte randomly generated
  nonces
- Hashes: SHA-256
- Key derivation: Scrypt with parameters `10000$8$1$`

## Key Management

Secret server keys must be rotated regularly. Because of how some keys are used,
it is not practical or possible to perform bulk data updates when
a key is rotated. Instead, the updates must be performed one-at-a-time,
at user sign in time. To support this, we keep a queue of old keys, and if necessary,
rewrite data using the most current key at user sign in.

Our convention for naming the old key queues is to append the configuration name
with `_queue`. Example: `hmac_fingerprinter_key_queue`. The value
should be a JSON-encoded list of keys, most recent first.

### Scenarios

We delineate different categories of key rotation scenarios.

#### Affects current session only

An example is asymmetric public/private x509 keys used between the IdP and service
providers. If we don't care about breaking existing user sessions, we can simply
rotate the keys in place and restart the application.

Applicable keys under this scenario:

* PKI
* `saml_passphrase`
* `session_encryption_key`

#### Affects long-term storage

An example is `attribute_encryption_key`. This key can be changed, and the old key added
to the `attribute_encryption_key_queue`. The next time the user signs in,
the `User.encrypted_email` column will be automatically updated after successful
authentication.

Applicable keys under this scenario:

* `attribute_encryption_key`
* `hmac_fingerprinter_key`

Some column attributes (like `User.encrypted_email`) can be bulk updated via a Rake task
because they do not require a user session. Others (like `Profile.ssn_signature`) are resistant
to bulk updates because they involve user data only available in plain text during a user session.

[NIST key management guidelines](http://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-57pt1r4.pdf)
suggest a maximum of two years for active use of this type of key.

Since these particular server-side keys function like passwords, we follow [NIST guidelines in 800-63-3](https://pages.nist.gov/800-63-3/sp800-63b.html#sec5)
per changing them:

> Verifiers SHOULD NOT require memorized secrets to be changed arbitrarily (e.g., periodically) unless there is evidence of compromise of the authenticator or a subscriber requests a change.

Thus we plan to rotate these keys infrequently (once a year), or if there is evidence that they have been compromised.

#### Affects local key encryption

When using a HSM like AWS KMS, key rotation is handled by the service so there is nothing
to do. However in local development or when `use_kms?` feature is off,
the `password_pepper` is used to encrypt PII keys. Changing `password_pepper` will invalidate
any existing encrypted PII and render it non-decryptable.

## Questions?

Contact us at 18F@gsa.gov.
