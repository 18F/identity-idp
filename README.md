# Ruby SAML Identity Provider (IdP)
[![Build Status](https://secure.travis-ci.org/lawrencepit/ruby-saml-idp.png)](http://travis-ci.org/lawrencepit/ruby-saml-idp?branch=master) [![Dependency Status](https://gemnasium.com/lawrencepit/ruby-saml-idp.png)](https://gemnasium.com/lawrencepit/ruby-saml-idp)

The ruby SAML Identity Provider library is for implementing the server side of SAML authentication. It allows your application to act as an IdP (Identity Provider) using the [SAML v2.0](http://en.wikipedia.org/wiki/Security_Assertion_Markup_Language) protocol. It provides a means for managing authentication requests and confirmation responses for SPs (Service Providers).

Setting up a "real" IdP is such an undertaking I didn't care for such an achievement. I wanted something very simple that just works without having to install extra components and setup extra infrastructure. In it's current form it's basic. This is because currently I use it for manual and end-to-end testing purposes of the Service Provider side only. It is reversed engineered from real-world SAML Responses sent by ADFS systems.


Installation and Usage
----------------------

Add this to your Gemfile:

    gem 'ruby-saml-idp'

### Not using rails?

Include `SamlIdp::Controller` and see the examples that use rails. It should be straightforward for you.

Basically you call `decode_SAMLRequest(params[:SAMLRequest])` on an incoming request and then use the value `saml_acs_url` to determine the source for which you need to authenticate a user. How you authenticate a user is entirely up to you.

Once a user has successfully authenticated on your system send the Service Provider a SAMLReponse by posting to `saml_acs_url` the parameter `SAMLResponse` with the return value from a call to `encode_SAMLResponse(user_email)`.

### Using rails?

Add to your `routes.rb` file, for example:

``` ruby
get '/saml/auth' => 'saml_idp#new'
post '/saml/auth' => 'saml_idp#create'
```

Create a controller that looks like this, customize to your own situation:

``` ruby
class SamlIdpController < SamlIdp::IdpController
  before_filter :find_account
  # layout 'saml_idp'

  def idp_authenticate(email, password)
    user = @account.users.where(:email => params[:email]).first
    user && user.valid_password?(params[:password]) ? user : nil
  end

  def idp_make_saml_response(user)
    encode_SAMLResponse(user.email)
  end

  private

    def find_account
      @subdomain = saml_acs_url[/https?:\/\/(.+?)\.example.com/, 1]
      @account = Account.find_by_subdomain(@subdomain)
      render :status => :forbidden unless @account.saml_enabled?
    end

end
```

The most minimal example controller would look like:

``` ruby
class SamlIdpController < SamlIdp::IdpController

  def idp_authenticate(email, password)
    true
  end

  def idp_make_saml_response(user)
    encode_SAMLResponse("you@example.com")
  end

end
```

Keys and Secrets
----------------

To generate the SAML Response it uses a default X.509 certificate and secret key... which isn't so secret. You can find them in `SamlIdp::Default`. The X.509 certificate is valid until year 2032. Obviously you shouldn't use these if you intend to use this in production environments. In that case, within the controller set the properties `x509_certificate` and `secret_key` using a `prepend_before_filter` callback within the current request context or set them globally via the `SamlIdp.config.x509_certificate` and `SamlIdp.config.secret_key` properties.

The fingerprint to use, if you use the default X.509 certificate of this gem, is:

```
9E:65:2E:03:06:8D:80:F2:86:C7:6C:77:A1:D9:14:97:0A:4D:F4:4D
```


Service Providers
-----------------

To act as a Service Provider which generates SAML Requests and can react to SAML Responses use the excellent [ruby-saml](https://github.com/onelogin/ruby-saml) gem.


Author
----------

Lawrence Pit, lawrence.pit@gmail.com, [lawrencepit.com](http://lawrencepit.com), [@lawrencepit](http://twitter.com/lawrencepit)


Copyright
-----------

Copyright (c) 2012 Lawrence Pit. See MIT-LICENSE for details.
