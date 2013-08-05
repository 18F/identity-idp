# Introduction

This is a personal note to how SAML works so its easier to keep track of what's going on.
Most of the online documentation seems to dance around specific details that are
important to understand with the standard.

# General concepts to understand

* **XML**: XML is pretty standard, look it up
* **XML Signing**: XML signing takes the initial body of a section of XML, takes a digest of that
  body using an x509 cert and secret key, and injects a new XML section describing the signature
  and how to verify its validity. This helps protect against XML tampering on the wire.
* **SAML**: I recommend a quick gloss-over the wikipedia article to get some
  context: http://en.wikipedia.org/wiki/SAML_2.0

# Terms

* SSO/IDP == app using this gem
* Service Provider(SP)/Client == app connecting externally to this service

# Workflow

Initially a Service Provider will provide to the IDP (this app) a public key for identification and validation
of various data exchanged (XML Signed).

When this SP wants to authenticate a user they will redirect the User's browser to
`GET <this_app>/saml/auth`. This will prompt the user to login (or potentially it will
auto-log them in) and will POST to the Service Provider's endpoint with a `SAMLResponse`.
The SAMLResponse is a signed XML document containing data describing the user
and its abilities.

# Sides

SAML virtually requires `metadata`. Metadata is used, in this protocol, to keep client and
IDP communicating with correct endpoints and requirements. Client and IDP periodically
ask each-others metadata endpoints to check for setting changes.
