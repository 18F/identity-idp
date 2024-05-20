require 'rails_helper'

RSpec.describe StoreSpMetadataInSession do
  describe '#call' do
    let(:request_id) { SecureRandom.uuid }
    let(:app_session) { {} }
    let(:instance) do
      StoreSpMetadataInSession.new(session: app_session, request_id: request_id)
    end

    context 'when a ServiceProviderRequestProxy is not found' do
      let(:request_id) { 'foo' }

      it 'does not set the session[:sp] hash' do
        expect { instance.call }.to_not change(app_session, :keys)
      end
    end

    context 'when a ServiceProviderRequest is found' do
      let(:issuer) { 'issuer' }
      let(:request_url) { 'http://issuer.gov' }
      let(:requested_attributes) { %w[email] }
      let(:request_acr) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }
      let(:request_vtr) { 'C1.C2' }
      let(:sp_request) do
        ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
          sp_request.issuer = issuer
          sp_request.url = request_url
          sp_request.requested_attributes = requested_attributes
          sp_request.acr_values = request_acr
          sp_request.vtr = request_vtr
        end
      end

      it 'copies the attributes on the ServiceProviderRequest into the session[:sp] hash' do
        instance.call(service_provider_request: sp_request)

        expect(app_session[:sp]).to eq(
          {
            issuer: issuer,
            acr_values: request_acr,
            request_url: request_url,
            request_id: request_id,
            requested_attributes: requested_attributes,
            vtr: request_vtr,
          },
        )
      end
    end
  end
end
