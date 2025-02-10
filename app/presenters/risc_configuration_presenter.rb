# frozen_string_literal: true

# https://openid.net/specs/openid-risc-profile-1_0-ID1.html#discovery
class RiscConfigurationPresenter
  include Rails.application.routes.url_helpers

  DELIVERY_METHOD_PUSH = 'https://schemas.openid.net/secevent/risc/delivery-method/push'

  def configuration
    {
      issuer: root_url,
      jwks_uri: api_openid_connect_certs_url,
      delivery_methods_supported: [
        DELIVERY_METHOD_PUSH,
      ],
      delivery: [
        {
          delivery_method: DELIVERY_METHOD_PUSH,
          url: api_risc_security_events_url,
        },
      ],
    }
  end

  def url_options
    {}
  end
end
