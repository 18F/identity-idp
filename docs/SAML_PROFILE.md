## SAML Profile
DRAFT ONLY

Standard:  SAML 2.0  
OASIS Reference: https://www.oasis-open.org/committees/tc_home.php?wg_abbrev=security  
OASIS SAML Wiki: https://wiki.oasis-open.org/security/FrontPage

### 1 Introduction
...

### 2 Hub Service Profile of SAML
The current profile is based on the SAML Web Browser SSO Profile.

#### 2.1 Web Browser SSO Profile
In the scenario supported by the Hub Service profile a principal attempts to access a resource at a service provider that requires a security context. The principal is authenticated by an identity provider and has additional attributes asserted by an attribute provider(s) which is then combined by the Hub Service and an assertion produced for consumption by the service provider. On consumption of the assertion the service provider may establish a security context for the principal. The Single Logout Profile is not supported by this profile. On redirection to the hub service following a successful authentication Identity Providers MUST close any authentication session that has been created (see 2.1.3.8). This profile is implemented using the SAML Authentication Request protocol and the SAML Attribute Query protocol. It uses several of the existing SAML profiles, namely the Web SSO Profile and Assertion Query/Request Profile. It is assumed that the principal is using a standard commercial browser and can authenticate to the identity provider by some means outside the scope of SAML. By default all user agent exchanges MUST utilise TLS 1.2 or higher. Message integrity and confidentiality will be maintained through the use of asymmetric key signing and encryption.

#### 2.1.1 Required Information
**Identification:** `urn:gov:gsa:SAML:2.0.profiles:idp-service:sso`

**Description:** A profile in which a central Identity Provider provides authenticated Identity attributes at requested level of assurances as well as brokering of Authentication requests to external Identity Providers.

#### 2.1.2 Profile Overview

...

#### 2.1.3 Profile Description

In this profile the centralized Identity Provider has two distinct roles. When processing authentication requests from a service provider the centralized Identity Provider is simply an Identity Provider. When sending authentication requests to external Identity Providers the centralized Identity Provider acts as a relying party. 

In the descriptions below the following are referred to:

**Single Sign-On Service**
This is the authentication request protocol endpoint at the centralized and external Identity Provider to which the `<AuthnRequest>` message is delivered by the user agent.

**Assertion Consumer Service**
This is the authentication request protocol endpoint at the Service Provider and at the centralized Identity Provider to which the `<Response>` message is delivered by the user agent.

SAML provides a RelayState mechanism that a service provider MAY use to augment the user experience. The service provider MUST reveal as little of the request as possible in the RelayState value.

