## Security

### Security architecture

We are utilizing the industry's best security practices with guidance from NIST and the latest [Digital Authentication Guidelines](https://pages.nist.gov/800-63-3/sp800-63-3.html). 

Our application is continuously monitored for CVE, OSVDB, XSS, SQL injection and many other types of vulnerabilities using [Hakiri](https://hakiri.io).

```
@jgrevich - hardened images, FIPS ? 
```


#### Encryption at rest

All PII is encrypted at rest with a symmetric key derived from the user's passphrase, using a NIST-approved
algorithm that relies on a hardware security module (HSM).

#### Encryption in transit

Every assertion of PII (Personally Identifiable Information) is encrypted during transit using TLS (transmitted over HTTPS) and additionally using industry standard [XML encryption](https://www.w3.org/TR/2002/REC-xmlenc-core-20021210/Overview.html) at the application layer to further protect against pilfered payloads. 

Our XML encryption approach uses the [xmlenc](https://github.com/digidentity/xmlenc) gem with
AES-256-CBC for the PII and RSA-OAEP-MGF1P for the key. The encrypted PII is signed with the Service Provider's
public key.

```
@jgrevich - reference details of our https certs/HSTS? 
```


#### Network security


```
@jgrevich - relevant network security? 
```


### Operations

The application and server-level health and availability is monitored using [New Relic](https://newrelic.com) and incident response is handled using [PagerDuty](https://pagerduty.com). 

We are currently implementing our own independent monitoring and transaction testing for accurate monitoring of system and key transaction health without relying on third parties.

```
@pkarman and @jgrevich - thoughts on:
Also, the fault tolerance of all of these components.  In other words, 
how do we protect against single points of failure (SPOF)
```


