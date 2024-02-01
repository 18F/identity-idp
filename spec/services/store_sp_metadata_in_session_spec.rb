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

    context 'when a ServiceProviderRequestProxy is found' do
      let(:issuer) { 'issuer' }
      let(:ial) { nil }
      let(:aal) { nil }
      let(:url) { 'http://issuer.gov' }
      let(:requested_attributes) { %w[email] }
      let(:biometric_comparison_required) { false }

      before do
        ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
          sp_request.issuer = issuer
          sp_request.ial = ial
          sp_request.aal = aal
          sp_request.url = url
          sp_request.requested_attributes = requested_attributes
          sp_request.biometric_comparison_required = biometric_comparison_required
        end

        instance.call
      end

      context 'IAL1 is requested' do
        let(:ial) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }

        it 'sets the session[:sp] hash' do
          expect(app_session[:sp]).to eq(
            {
              issuer: 'issuer',
              aal_level_requested: nil,
              piv_cac_requested: false,
              phishing_resistant_requested: false,
              ial: 1,
              ial2: false,
              ialmax: false,
              request_url: 'http://issuer.gov',
              request_id: request_id,
              requested_attributes: %w[email],
              biometric_comparison_required: false,
            },
          )
        end
      end

      context 'when IAL2 and AAL3 are requested' do
        let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
        let(:aal) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }

        it 'sets the session[:sp] hash' do
          expect(app_session[:sp]).to eq(
            {
              issuer: 'issuer',
              aal_level_requested: 3,
              piv_cac_requested: false,
              phishing_resistant_requested: true,
              ial: 2,
              ial2: true,
              ialmax: false,
              request_url: 'http://issuer.gov',
              request_id: request_id,
              requested_attributes: %w[email],
              biometric_comparison_required: false,
            },
          )
        end
      end

      context 'when IAL2 and phishing-resistant are requested' do
        let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
        let(:aal) { Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF }

        it 'sets the session[:sp] hash' do
          expect(app_session[:sp]).to eq(
            {
              issuer: 'issuer',
              aal_level_requested: 2,
              piv_cac_requested: false,
              phishing_resistant_requested: true,
              ial: 2,
              ial2: true,
              ialmax: false,
              request_url: 'http://issuer.gov',
              request_id: request_id,
              requested_attributes: %w[email],
              biometric_comparison_required: false,
            },
          )
        end
      end

      context 'when biometric comparison is requested' do
        let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
        let(:aal) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }
        let(:biometric_comparison_required) { true }

        it 'sets the session[:sp] hash' do
          expect(app_session[:sp]).to eq(
            {
              issuer: 'issuer',
              aal_level_requested: 3,
              piv_cac_requested: false,
              phishing_resistant_requested: true,
              ial: 2,
              ial2: true,
              ialmax: false,
              request_url: 'http://issuer.gov',
              request_id: request_id,
              requested_attributes: %w[email],
              biometric_comparison_required: true,
            },
          )
        end
      end
    end
  end
end
