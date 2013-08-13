# Ruby SAML Identity Provider (IdP)
Forked from https://github.com/lawrencepit/ruby-saml-idp

The ruby SAML Identity Provider library is for implementing the server side of SAML authentication. It allows
your application to act as an IdP (Identity Provider) using the
[SAML v2.0](http://en.wikipedia.org/wiki/Security_Assertion_Markup_Language)
protocol. It provides a means for managing authentication requests and confirmation responses for SPs (Service Providers).

This was originally setup by @lawrencepit to test SAML Clients. I took it closer to a real
SAML IDP implementation.

# Installation and Usage

Add this to your Gemfile:

    gem 'saml_idp'

## Not using rails?
Include `SamlIdp::Controller` and see the examples that use rails. It should be straightforward for you.

Basically you call `decode_request(params[:SAMLRequest])` on an incoming request and then use the value
`saml_acs_url` to determine the source for which you need to authenticate a user. How you authenticate
a user is entirely up to you.

Once a user has successfully authenticated on your system send the Service Provider a SAMLReponse by
posting to `saml_acs_url` the parameter `SAMLResponse` with the return value from a call to
`encode_response(user_email)`.

## Using rails?
Add to your `routes.rb` file, for example:

``` ruby
get '/saml/auth' => 'saml_idp#new'
get '/saml/metadata' => 'saml_idp#show'
post '/saml/auth' => 'saml_idp#create'
```

Create a controller that looks like this, customize to your own situation:

``` ruby
class SamlIdpController < SamlIdp::IdpController
  def idp_authenticate(email, password) # not using params intentionally
    user = User.by_email(email).first
    user && user.valid_password?(password) ? user : nil
  end
  private :idp_authenticate

  def idp_make_saml_response(found_user) # not using params intentionally
    encode_response found_user
  end
  private :idp_make_saml_response
end
```

# Keys and Secrets
To generate the SAML Response it uses a default X.509 certificate and secret key... which isn't so secret.
You can find them in `SamlIdp::Default`. The X.509 certificate is valid until year 2032.
Obviously you shouldn't use these if you intend to use this in production environments. In that case,
within the controller set the properties `x509_certificate` and `secret_key` using a `prepend_before_filter`
callback within the current request context or set them globally via the `SamlIdp.config.x509_certificate`
and `SamlIdp.config.secret_key` properties.

The fingerprint to use, if you use the default X.509 certificate of this gem, is:

```
9E:65:2E:03:06:8D:80:F2:86:C7:6C:77:A1:D9:14:97:0A:4D:F4:4D
```


# Service Providers
To act as a Service Provider which generates SAML Requests and can react to SAML Responses use the
excellent [ruby-saml](https://github.com/onelogin/ruby-saml) gem.


# Author
Jon Phenow, jon.phenow@sportngin.com
Lawrence Pit, lawrence.pit@gmail.com, lawrencepit.com, @lawrencepit

# Copyright
Copyright (c) 2012 Sport Ngin.
Portions Copyright (c) 2010 OneLogin, LLC
Portions Copyright (c) 2012 Lawrence Pit (http://lawrencepit.com)

See LICENSE for details.
