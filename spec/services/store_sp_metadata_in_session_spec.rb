require 'rails_helper'

describe StoreSpMetadataInSession do
  describe '#call' do
    context 'when a ServiceProviderRequestProxy is not found' do
      it 'does not set the session[:sp] hash' do
        allow(Rails.logger).to receive(:info)
        app_session = {}
        instance = StoreSpMetadataInSession.new(session: app_session, request_id: 'foo')
        info_hash = {
          event: 'StoreSpMetadataInSession',
          request_id_present: true,
          sp_request_class: 'NullServiceProviderRequest',
        }.to_json

        expect { instance.call }.to_not change(app_session, :keys)
        expect(Rails.logger).to have_received(:info).with(info_hash)
      end
    end

    context 'when a ServiceProviderRequestProxy is found' do
      it 'sets the session[:sp] hash' do
        allow(Rails.logger).to receive(:info)

        app_session = {}
        request_id = SecureRandom.uuid
        ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
          sp_request.issuer = 'issuer'
          sp_request.ial = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
          sp_request.url = 'http://issuer.gov'
          sp_request.requested_attributes = %w[email]
        end
        instance = StoreSpMetadataInSession.new(session: app_session, request_id: request_id)

        info_hash = {
          event: 'StoreSpMetadataInSession',
          request_id_present: true,
          sp_request_class: 'ServiceProviderRequest',
        }.to_json

        app_session_hash = {
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
        }

        instance.call
        expect(Rails.logger).to have_received(:info).with(info_hash)
        expect(app_session[:sp]).to eq app_session_hash
      end
    end

    context 'when IAL2 and AAL3 are requested' do
      it 'sets the session[:sp] hash' do
        allow(Rails.logger).to receive(:info)

        app_session = {}
        request_id = SecureRandom.uuid
        ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
          sp_request.issuer = 'issuer'
          sp_request.ial = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
          sp_request.aal = Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
          sp_request.url = 'http://issuer.gov'
          sp_request.requested_attributes = %w[email]
        end
        instance = StoreSpMetadataInSession.new(session: app_session, request_id: request_id)

        info_hash = {
          event: 'StoreSpMetadataInSession',
          request_id_present: true,
          sp_request_class: 'ServiceProviderRequest',
        }.to_json

        app_session_hash = {
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
        }

        instance.call
        expect(Rails.logger).to have_received(:info).with(info_hash)
        expect(app_session[:sp]).to eq app_session_hash
      end
    end

    context 'when IAL2 and phishing-resistant are requested' do
      it 'sets the session[:sp] hash' do
        allow(Rails.logger).to receive(:info)

        app_session = {}
        request_id = SecureRandom.uuid
        ServiceProviderRequestProxy.find_or_create_by(uuid: request_id) do |sp_request|
          sp_request.issuer = 'issuer'
          sp_request.ial = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
          sp_request.aal = Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF
          sp_request.url = 'http://issuer.gov'
          sp_request.requested_attributes = %w[email]
        end
        instance = StoreSpMetadataInSession.new(session: app_session, request_id: request_id)

        info_hash = {
          event: 'StoreSpMetadataInSession',
          request_id_present: true,
          sp_request_class: 'ServiceProviderRequest',
        }.to_json

        app_session_hash = {
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
        }

        instance.call
        expect(Rails.logger).to have_received(:info).with(info_hash)
        expect(app_session[:sp]).to eq app_session_hash
      end
    end
  end
end
