require 'rails_helper'

RSpec.describe SecurityEventsController do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:identity) { IdentityLinker.new(user, service_provider.issuer).link_identity }
  let(:service_provider) { create(:service_provider) }

  let(:rp_private_key) do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys/saml_test_sp.key')),
    )
  end

  describe '#create' do
    let(:jwt_payload) do
      {
        iss: identity.service_provider,
        jti: SecureRandom.urlsafe_base64,
        iat: Time.zone.now.to_i,
        aud: api_security_events_url,
        events: {
          SecurityEvent::CREDENTIAL_CHANGE_REQUIRED => {
            subject: {
              subject_type: 'iss_sub',
              iss: root_url,
              sub: identity.uuid,
            },
          },
        },
      }
    end

    let(:jwt) { JWT.encode(jwt_payload, rp_private_key, 'RS256') }

    it 'creates a security event record' do
      expect { post :create, body: jwt, as: :secevent_jwt }.
        to(change { SecurityEvent.count }).by(1)

      expect(response.body).to be_empty
      expect(response.code.to_i).to eq(202) # Accepted
    end

    context 'with a bad request' do
      before { jwt_payload[:aud] = 'http://bad.example' }

      it 'renders an error response and does not create a security event record' do
        expect { post :create, body: jwt, as: :secevent_jwt }.
          to_not(change { SecurityEvent.count })

        expect(response).to be_bad_request

        json = JSON.parse(response.body).with_indifferent_access

        expect(json[:err]).to eq(SecurityEventForm::ErrorCodes::JWT_AUD)
        expect(json[:description]).to include("expected #{api_security_events_url}")
      end
    end
  end
end
