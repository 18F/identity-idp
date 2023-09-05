require 'rails_helper'

RSpec.describe Risc::SecurityEventsController do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:identity) { IdentityLinker.new(user, service_provider).link_identity }
  let(:service_provider) { create(:service_provider) }

  let(:rp_private_key) do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys', 'saml_test_sp.key')),
    )
  end

  describe '#create' do
    let(:action) { post :create, body: jwt, as: :secevent_jwt }
    let(:jti) { SecureRandom.urlsafe_base64 }
    let(:event_type) { SecurityEvent::AUTHORIZATION_FRAUD_DETECTED }
    let(:jwt_payload) do
      {
        iss: identity.service_provider,
        jti: jti,
        iat: Time.zone.now.to_i,
        aud: api_risc_security_events_url,
        events: {
          event_type => {
            subject: {
              subject_type: 'iss-sub',
              iss: root_url,
              sub: AgencyIdentityLinker.new(identity).link_identity.uuid,
            },
          },
        },
      }
    end

    let(:jwt) { JWT.encode(jwt_payload, rp_private_key, 'RS256', typ: 'secevent+jwt') }

    it 'creates a security event record' do
      expect { action }.
        to(change { SecurityEvent.count }.by(1))

      expect(response.body).to be_empty
      expect(response.code.to_i).to eq(202) # Accepted
    end

    it 'tracks an successful in analytics' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with('RISC: Security event received',
             client_id: service_provider.issuer,
             error_code: nil,
             errors: {},
             jti: jti,
             success: true,
             user_id: user.uuid)

      action
    end

    context 'with a bad request' do
      before { jwt_payload[:aud] = 'http://bad.example' }

      it 'renders an error response and does not create a security event record' do
        expect { action }.
          to_not(change { SecurityEvent.count })

        expect(response).to be_bad_request

        json = JSON.parse(response.body).with_indifferent_access

        expect(json[:err]).to eq(SecurityEventForm::ErrorCodes::JWT_AUD)
        expect(json[:description]).to include("expected #{api_risc_security_events_url}")
      end

      it 'tracks an error event in analytics' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('RISC: Security event received',
               client_id: service_provider.issuer,
               error_code: SecurityEventForm::ErrorCodes::JWT_AUD,
               errors: kind_of(Hash),
               error_details: kind_of(Hash),
               jti: jti,
               success: false,
               user_id: user.uuid)

        action
      end
    end
  end
end
