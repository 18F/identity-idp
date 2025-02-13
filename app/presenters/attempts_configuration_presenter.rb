# frozen_string_literal: true

# https://openid.net/specs/openid-sharedsignals-framework-1_0-ID3.html#name-transmitter-configuration-m
class AttemptsConfigurationPresenter
  include Rails.application.routes.url_helpers

  DELIVERY_METHOD_POLL = 'https://schemas.openid.net/secevent/risc/delivery-method/poll'

  def configuration
    {
      issuer: root_url,
      jwks_uri: api_openid_connect_certs_url,
      delivery_methods_supported: [
        DELIVERY_METHOD_POLL,
      ],
      delivery: [
        {
          delivery_method: DELIVERY_METHOD_POLL,
          url: api_attempts_poll_url,
        },
      ],
      status_endpoint: api_attempts_status_url,
    }
  end

  def url_options
    {}
  end
end
