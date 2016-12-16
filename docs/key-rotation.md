Key Rotation
=============

# Introduction

Secret server keys must be rotated regularly. Because of how some keys are used,
it is not practical or possible to perform bulk data updates when
a key is rotated. Instead, the updates must be performed one-at-a-time,
at user sign in time. To support this, we keep a queue of old keys, and if necessary,
rewrite data using the most current key at user sign in.

Our convention for naming the old key queues is to append the configuration name
with `_queue`. Example: `hmac_fingerprinter_key_queue`. The value
should be a JSON-encoded list of keys, most recent first.

# Scenarios

We delineate different categories of key rotation scenarios.

## Affects current session only

An example is asymmetric public/private x509 keys used between the IdP and service
providers. If we don't care about breaking existing user sessions, we can simply
rotate the keys in place and restart the application.

Applicable keys under this scenario:

* PKI
* `saml_passphrase`
* `session_encryption_key`

## Affects long-term storage

An example is `email_encryption_key`. This key can be changed, and the old key added
to the `email_encryption_key_queue`. The next time the user signs in,
the `User.encrypted_email` column will be automatically updated after successful
authentication.

Applicable keys under this scenario:

* `email_encryption_key`
* `hmac_fingerprinter_key`

## Affects local key encryption

When using a HSM like AWS KMS, key rotation is handled by the service so there is nothing
to do. However in local development or when `use_kms?` feature is off,
the `password_pepper` is used to encrypt PII keys. Changing `password_pepper` will invalidate
any existing encrypted PII and render it non-decryptable.
