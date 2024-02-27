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
      let(:request_acr) { nil }
      let(:request_vtr) { nil }
      let(:biometric_comparison_required) { false }
      let(:sp_request) do
        ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
          sp_request.issuer = issuer
          sp_request.url = request_url
          sp_request.requested_attributes = requested_attributes
          sp_request.biometric_comparison_required = biometric_comparison_required
          sp_request.acr_values = request_acr
          sp_request.vtr = request_vtr
        end
      end

      before do
        instance.call(service_provider_request: sp_request)
      end

      context 'IAL1 is requested with ACRs' do
        let(:request_acr) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: false,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when IAL2 and AAL3 are requested with ACRs' do
        let(:request_acr) do
          [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
           Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF].join(' ')
        end

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: false,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when IAL2 and phishing-resistant are requested with ACRs' do
        let(:request_acr) do
          [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
           Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF].join(' ')
        end

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: false,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when biometric comparison is requested with ACRs' do
        let(:request_acr) do
          [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
           Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF].join(' ')
        end
        let(:biometric_comparison_required) { true }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: true,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when MFA is requested using a VTR' do
        let(:request_vtr) { ['C1'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: false,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when MFA and biometric comparison are requested using a VTR' do
        context 'using VTR' do
          let(:request_vtr) { ['C1.Pb'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                acr_values: request_acr,
                piv_cac_requested: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: true,
                vtr: request_vtr,
              },
            )
          end
        end
      end

      context 'when AAL2 and proofing are requested using a VTR' do
        let(:request_vtr) { ['C2.P1'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: false,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when AAL2 and biometric comparison are requested using a VTR' do
        let(:request_vtr) { ['C2.Pb'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: true,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when phishing resistant ID and proofing are requested using a VTR' do
        let(:request_vtr) { ['Ca.P1'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: false,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when phishing resistant and ID biometric comparison are requested using a VTR' do
        let(:request_vtr) { ['Ca.Pb'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: true,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when PIV/CAC and proofing are requested using a VTR' do
        let(:request_vtr) { ['Cb.P1'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: true,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: false,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'when PIV/CAC and biometric comparison are requested using a VTR' do
        let(:request_vtr) { ['Cb.Pb'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: true,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: true,
              vtr: request_vtr,
            },
          )
        end
      end

      context 'IAL2 proofing requested with no authentication requirement using a VTR' do
        let(:request_vtr) { ['Pb'] }

        it 'sets the session[:sp] hash correctly' do
          expect(app_session[:sp]).to eq(
            {
              issuer: issuer,
              acr_values: request_acr,
              piv_cac_requested: false,
              request_url: request_url,
              request_id: request_id,
              requested_attributes: requested_attributes,
              biometric_comparison_required: true,
              vtr: request_vtr,
            },
          )
        end
      end
    end
  end
end
