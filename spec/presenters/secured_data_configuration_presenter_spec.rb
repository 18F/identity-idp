require 'rails_helper'

RSpec.describe SecuredDataConfigurationPresenter do
  include Rails.application.routes.url_helpers

  subject { SecuredDataConfigurationPresenter.new }

  describe '#configuration' do
    let(:configuration) { subject.configuration }

    it 'includes information about the RISC integration' do
      aggregate_failures do
        expect(configuration[:issuer]).to eq(root_url)
        expect(configuration[:jwks_uri]).to eq(api_secured_data_certs_url)
        expect(configuration[:delivery_methods_supported])
          .to eq([SecuredDataConfigurationPresenter::DELIVERY_METHOD_POLL])

        expect(configuration[:delivery]).to eq(
          [
            delivery_method: SecuredDataConfigurationPresenter::DELIVERY_METHOD_POLL,
            url: api_secured_data_poll_url,
          ],
        )

        expect(configuration[:status_endpoint]).to eq(api_secured_data_status_url)
      end
    end
  end
end
