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
      # old-style SP requests
      context 'and the `use_vot_in_sp_requests` config bflag is false' do
        let(:issuer) { 'issuer' }
        let(:ial) { nil }
        let(:aal) { nil }
        let(:request_url) { 'http://issuer.gov' }
        let(:requested_attributes) { %w[email] }
        let(:biometric_comparison_required) { false }

        before do
          allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(false)

          ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
            sp_request.issuer = issuer
            sp_request.ial = ial
            sp_request.aal = aal
            sp_request.url = request_url
            sp_request.requested_attributes = requested_attributes
            sp_request.biometric_comparison_required = biometric_comparison_required
          end

          instance.call
        end

        matcher :have_default_non_vot_values do
          match do |actual|
            actual.slice(:issuer, :request_url, :request_id) ==
              {
                issuer: issuer,
                request_url: request_url,
                request_id: request_id,
              }
          end
        end

        context 'IAL1 is requested' do
          let(:ial) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }
          let(:sp_hash) { app_session[:sp] }

          it 'sets the session[:sp] hash correctly' do
            expect(sp_hash).to have_default_non_vot_values
            expect(sp_hash).to eq(
              {
                issuer: issuer,
                aal_level_requested: nil,
                piv_cac_requested: false,
                phishing_resistant_requested: false,
                ial: 1,
                ial2: false,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: false,
              },
            )
          end
        end

        context 'when IAL2 and AAL3 are requested' do
          let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
          let(:aal) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 3,
                piv_cac_requested: false,
                phishing_resistant_requested: true,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: false,
              },
            )
          end
        end

        context 'when IAL2 and phishing-resistant are requested' do
          let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
          let(:aal) { Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 2,
                piv_cac_requested: false,
                phishing_resistant_requested: true,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: false,
              },
            )
          end
        end

        context 'when biometric comparison is requested' do
          let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
          let(:aal) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }
          let(:biometric_comparison_required) { true }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 3,
                piv_cac_requested: false,
                phishing_resistant_requested: true,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: true,
              },
            )
          end
        end
      end

      # new-style SP requests
      context 'and the `use_vot_in_sp_requests` config flag is true' do
        let(:issuer) { 'issuer' }
        let(:request_url) { 'http://issuer.gov' }
        let(:requested_attributes) { %w[email] }
        let(:request_acr) { nil }
        let(:request_vtr) { [] }

        before do
          allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)

          sp_request = ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
            sp_request.issuer = issuer
            sp_request.url = request_url
            sp_request.requested_attributes = requested_attributes
            sp_request.acr_values = request_acr
            sp_request.vtr = request_vtr
          end

          instance.call(service_provider_request: sp_request)
        end

        context 'when MFA is requested' do
          let(:request_vtr) { ['C1'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 1,
                piv_cac_requested: false,
                phishing_resistant_requested: false,
                ial: 1,
                ial2: false,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: false,
              },
            )
          end
        end

        context 'when MFA and biometric comparison are requested' do
          let(:request_vtr) { ['C1.Pb'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 2,
                piv_cac_requested: false,
                phishing_resistant_requested: false,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: true,
              },
            )
          end
        end

        context 'when AAL2 and proofing are requested' do
          let(:request_vtr) { ['C2.P1'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 2,
                piv_cac_requested: false,
                phishing_resistant_requested: false,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: false,
              },
            )
          end
        end

        context 'when AAL2 and biometric comparison are requested' do
          let(:request_vtr) { ['C2.Pb'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 2,
                piv_cac_requested: false,
                phishing_resistant_requested: false,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: true,
              },
            )
          end
        end

        context 'when phishing resistant ID and proofing are requested' do
          let(:request_vtr) { ['Ca.P1'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                 aal_level_requested: 3,
                 piv_cac_requested: false,
                 phishing_resistant_requested: true,
                 ial: 2,
                 ial2: true,
                 ialmax: false,
                 request_url: request_url,
                 request_id: request_id,
                 requested_attributes: requested_attributes,
                 biometric_comparison_required: false,
              },
            )
          end
        end

        context 'when phishing resistant and ID biometric comparison are requested' do
          let(:request_vtr) { ['Ca.Pb'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 3,
                piv_cac_requested: false,
                phishing_resistant_requested: true,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: true,
              },
            )
          end
        end

        context 'when PIV/CAC and proofing are requested' do
          let(:request_vtr) { ['Cb.P1'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 2,
                piv_cac_requested: true,
                phishing_resistant_requested: false,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: false,
              },
            )
          end
        end

        context 'when PIV/CAC and biometric comparison are requested' do
          let(:request_vtr) { ['Cb.Pb'] }

          it 'sets the session[:sp] hash correctly' do
            expect(app_session[:sp]).to eq(
              {
                issuer: issuer,
                aal_level_requested: 2,
                piv_cac_requested: true,
                phishing_resistant_requested: false,
                ial: 2,
                ial2: true,
                ialmax: false,
                request_url: request_url,
                request_id: request_id,
                requested_attributes: requested_attributes,
                biometric_comparison_required: true,
              },
            )
          end
        end
      end
    end
  end
end
