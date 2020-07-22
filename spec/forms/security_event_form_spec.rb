require 'rails_helper'

RSpec.describe SecurityEventForm do
  include Rails.application.routes.url_helpers

  subject(:form) { SecurityEventForm.new(body: jwt) }

  let(:user) { create(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:rp_private_key) do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys/saml_test_sp.key')),
    )
  end
  let(:identity) { IdentityLinker.new(user, service_provider.issuer).link_identity }

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
            sub: subject_sub,
          },
        },
      },
    }
  end

  let(:subject_sub) { identity.uuid }
  let(:jwt) { JWT.encode(jwt_payload, rp_private_key, 'RS256') }

  describe '#submit' do
    subject(:submit) { form.submit }

    it 'creates a SecurityEvent record' do
      expect { submit }.to(change { SecurityEvent.count }.by(1))

      security_event = SecurityEvent.last
      aggregate_failures do
        expect(security_event.jti).to eq(jwt_payload[:jti])
        expect(security_event.event_type).to eq(SecurityEvent::CREDENTIAL_CHANGE_REQUIRED)
        expect(security_event.issuer).to eq(service_provider.issuer)
        expect(security_event.user).to eq(user)
      end
    end

    context 'when request is invalid' do
      let(:jwt) { 'bbb.bbb.bbb' }

      it 'does not create a SecurityEvent record' do
        expect { submit }.to_not(change { SecurityEvent.count })
      end
    end

    context 'analytics attributes' do
      it 'contains the SP, user ID, error code' do
        response = submit

        expect(response.to_h).to include(
          user_id: user.uuid,
          client_id: service_provider.issuer,
          error_code: nil,
        )
      end

      context 'with an invalid request' do
        before { jwt_payload[:aud] = 'https://bad.example' }

        it 'contains the error code' do
          response = submit

          expect(response.to_h).to include(error_code: 'jwtAud')
        end
      end
    end
  end

  describe '#valid?' do
    subject(:valid?) { form.valid? }

    it 'is valid with a valid form' do
      aggregate_failures do
        expect(valid?).to eq(true)
        expect(form.errors).to be_blank
      end
    end

    context 'JWT' do
      context 'with a body that is not a JWT' do
        let(:jwt) { 'bbb.bbb.bbb' }
        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:jwt]).to include('Invalid segment encoding')
          expect(form.error_code).to eq('jwtParse')
        end
      end

      context 'when signed with a different key than registered to the SP' do
        let(:rp_private_key) do
          OpenSSL::PKey::RSA.new(
            File.read(Rails.root.join('keys/oidc.key')),
          )
        end

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:jwt]).to include('Signature verification raised')
        end
      end
    end

    context 'aud' do
      context 'with a wrong audience endpoint URL' do
        before { jwt_payload[:aud] = 'https://bad.example' }
        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.error_code).to eq('jwtAud')
          expect(form.errors[:aud]).
            to include("invalid aud claim, expected #{api_security_events_url}")
        end
      end
    end

    context 'iss' do
      context 'with an unknown issuer' do
        before { jwt_payload[:iss] = 'not.valid.issuer' }
        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:iss]).to include('invalid issuer')
        end
      end
    end

    context 'event type' do
      context 'with no events' do
        before { jwt_payload.delete(:events) }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:event_type]).to include('missing event')
          expect(form.error_code).to eq('setData')
        end
      end

      context 'with a bad event type' do
        before do
          event = jwt_payload[:events].delete(SecurityEvent::CREDENTIAL_CHANGE_REQUIRED)
          jwt_payload[:events]['wrong-event-type'] = event
        end

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:event_type]).to include('unsupported event type wrong-event-type')
          expect(form.error_code).to eq('setType')
        end
      end

      context 'with an additional event type' do
        before { jwt_payload[:events]['extra-event'] = { subject: 'blah' } }

        it 'is valid' do
          expect(valid?).to eq(true)
          expect(form.error_code).to be_nil
        end
      end
    end

    context 'subject_type' do
      context 'with a bad subject type' do
        before do
          _event_name, event = jwt_payload[:events].first
          event[:subject][:subject_type] = 'email'
        end

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:subject_type]).to include('subject_type must be iss_sub')
        end
      end
    end

    context 'sub' do
      context 'with a bad uuid' do
        let(:subject_sub) { 'aaa' }
        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.error_code).to eq('setData')
          expect(form.errors[:sub]).to include('invalid sub claim')
        end
      end

      context 'with a uuid for a different identity' do
        let(:subject_sub) { create(:identity).uuid }
        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.error_code).to eq('setData')
          expect(form.errors[:sub]).to include('invalid sub claim')
        end
      end
    end
  end
end
