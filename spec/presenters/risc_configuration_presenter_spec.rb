require 'rails_helper'

RSpec.describe RiscConfigurationPresenter do
  include Rails.application.routes.url_helpers

  subject(:presenter) { RiscConfigurationPresenter.new }

  describe '#configuration' do
    subject(:configuration) { presenter.configuration }

    it 'includes information about the RISC integration' do
      aggregate_failures do
        expect(configuration[:issuer]).to eq(root_url)
        expect(configuration[:jwks_uri]).to eq(api_openid_connect_certs_url)
        expect(configuration[:delivery_methods_supported])
          .to eq([RiscConfigurationPresenter::DELIVERY_METHOD_PUSH])

        expect(configuration[:delivery].first).to eq(
          delivery_method: RiscConfigurationPresenter::DELIVERY_METHOD_PUSH,
          url: api_risc_security_events_url,
        )
      end
    end
  end
end
