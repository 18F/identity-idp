## Security

### Security architecture

We are utilizing the industry's best security practices with guidance from NIST and the latest [Digital Authentication Guidelines](https://pages.nist.gov/800-63-3/sp800-63-3.html).

Our application is continuously monitored for CVE, OSVDB, XSS, SQL injection and many other types of vulnerabilities using [Snyk](https://snyk.io).


#### Encryption at rest

All PII is encrypted at rest with a symmetric key derived from the user's passphrase, using a NIST-approved pbkdf2 algorithm that relies on an AWS Key Management Service (KMS) which are NIST PUB 140-2 [validated](https://csrc.nist.gov/projects/cryptographic-module-validation-program/Certificate/3139) HSMs.

#### Encryption in transit

Every assertion of PII (Personally Identifiable Information) is encrypted during transit using TLS (transmitted over HTTPS) and additionally using industry standard [XML encryption](https://www.w3.org/TR/2002/REC-xmlenc-core-20021210/Overview.html) at the application layer to further protect against pilfered payloads.

Our XML encryption approach uses the [xmlenc](https://github.com/digidentity/xmlenc) gem with AES-256-CBC for the PII and RSA-OAEP-MGF1P for the key. The encrypted PII is signed with the Service Provider's
public key.


#### Network security

We use [Rack::Attack](https://github.com/kickstarter/rack-attack) to throttle abusive requests and brute-force authentication attempts.


### Operations

The application and server-level health and availability is monitored using [New Relic](https://newrelic.com) and incident response is handled using [Opsgenie](https://www.atlassian.com/software/opsgenie).

We implemented our own independent monitoring and transaction testing for accurate monitoring of system and key transaction health without relying on third parties.
