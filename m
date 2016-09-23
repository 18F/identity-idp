**Why**: All PII must be encrypted at rest.
Storing attributes in a single JSON blob makes this much easier.

**How**:

The encryption architecture is similar to a hotel. Each user gets their
own room. The hotel management has a master key to every room.
Inside each room is a safe, where the PII itself is stored,
and only the user has the combination to the safe. If the user loses
their room key, the management can replace it. If the user loses
the safe combination, the safe can never be opened.

All PII is encrypted at rest in 2 layers: once with a unique
private key encrypted with the user's own password, and once
with a server-wide private key. The user's private key
is enclosed within the server-wide-key encrypted payload.

Encryption happens at the time a Profile is saved. Each time the
user logs in, the PII is decrypted using the password the user
provides. The PII is then re-encrypted within the session, using
the server-wide private key (just one layer of encryption).
The PII can be decrypted as-needed during the session (as for
SAML responses and displaying profile information to the user)
using the server-wide key.

NOTE: This PR does not include the following features, which
will be implemented in a follow-on PR:

* re-encrypt PII when password changed
* mark profile.active=false when password reset
* encrypt IdV session at rest
