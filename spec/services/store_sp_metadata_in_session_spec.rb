require 'rails_helper'

describe StoreSpMetadataInSession do
  describe '#call' do
    context 'when a ServiceProviderRequest is not found' do
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

    context 'when a ServiceProviderRequest is found' do
      it 'sets the session[:sp] hash' do
        allow(Rails.logger).to receive(:info)

        app_session = {}
        request_id = SecureRandom.uuid
        ServiceProviderRequest.find_or_create_by(uuid: request_id) do |sp_request|
          sp_request.issuer = 'issuer'
          sp_request.loa = 'loa1'
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
          loa3: false,
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
