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

## Implementation

To address all these design goals we have implemented a multi-factor
encryption model.

When a user first creates an account, we use the user's password,
a server-controlled random string, and a hardware security module (HSM)
to create an encryption key.
Any time the user gives us private personal information
we use that encryption key to encrypt the personal information.
The private PII may only be decrypted if all three factors are present: the HSM,
the user's password, and the random string.

All random strings are generated using the openssl library via
the Ruby [SecureRandom module](https://ruby-doc.org/stdlib-2.3.0/libdoc/securerandom/rdoc/SecureRandom.html).

It is important to note that the HSM factor strengthens the model in a
way different than the other two factors, which rely on keeping them secret.
Because the HSM is tied to a physical object, brute force attacks on our database
would need to happen in proximity to the HSM, i.e., within our AWS environment, which greatly
reduces the attack surface. A bad actor with a copy of the database cannot
apply their own computing power to brute force cracking of passwords.

Based on consultation with the [National Institute of Standards and Technology](https://www.nist.gov/)
we follow these steps to create the encryption key:

* generate and store a random, 160-bit string as `salt`
* using the user's password and the `salt`, create a [SCrypt](https://github.com/pbhogan/scrypt) hash
* split the SCrypt hash into two 128-bit strings, `Z1` and `Z2`
* generate a random 256-bit string `AssignedSecret` (`R`)
* using the HSM, encrypt `AssignedSecret` as `EncryptedAssignedSecret` (`encrypted_R`)
* calculate the [XOR](https://en.wikipedia.org/wiki/Exclusive_or)
  of `EncryptedAssignedSecret` and `Z1` as `MaskedCiphertext` (`D`)
* store `MaskedCiphertext` with the user record
* create a SHA-256 hash of the concatenation of `Z2` and `MaskedCiphertext` called `CEK` (`E`)
* create a SHA-256 hash of `CEK` called `PasswordHash`
* store `PasswordHash` with the user record
* using the key `CEK`, encrypt the PII using AES GCM 256-bit encryption
  as `EncryptedPII` (`C`)
* store `EncryptedPII` with the user record
* do *not* store plaintext PII, `AssignedSecret` or `CEK`

You can review [the tests for this model in our public repository](https://github.com/18F/identity-idp/blob/master/spec/services/pii/nist_encryption_spec.rb). We have also documented some [example code](https://github.com/18F/identity-idp/blob/master/docs/encryption-examples.md) that can be used to re-create the process we use to encrypt and decrypt PII.

Since the user's password is an integral part of this multi-factor
model, if the user forgets their password, the PII may not be recovered.
To mitigate that loss, we repeat the process above using the user recovery
code, a randomly generated 128-bit string the user is given when they create
their account. The recovery code can be used once as a replacement for their
second authentication factor (e.g. if they lose their mobile phone). It also functions
as a backup password for encrypted PII.

On login, the decryption process is applied, and the PII is re-encrypted
with the same multi-factor model, using a server-controlled key in place of the user
password so that the PII can be accessed by the server for the life of the session.

When PII needs to be accessed (e.g. to show a user their SSN, or to assert to a
government relying party) the ciphertext is
read from the session, decrypted using the server-controlled key, and the
particular data elements needed are extracted.

When sessions expire, the ciphertext they contain is deleted.

When a user loses their password and requests a reset, if the user has
encrypted private PII stored with us, they are also prompted for their recovery code.
The recovery code acts as a backup password. Their PII can be decrypted,
a new recovery code generated, and the PII re-encrypted. If the user loses their
recovery code and their password, they will need to go through the proofing process
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
- Key derivation: Scrypt with `:max_time` of 0.5seconds

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
