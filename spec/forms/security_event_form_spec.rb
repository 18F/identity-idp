require 'rails_helper'

RSpec.describe SecurityEventForm do
  include Rails.application.routes.url_helpers

  subject(:form) { SecurityEventForm.new(body: jwt) }

  let(:user) { create(:user) }
  let(:agency) { create(:agency) }
  let(:service_provider) { create(:service_provider, agency_id: agency.id) }
  let(:rp_private_key) do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys', 'saml_test_sp.key')),
    )
  end
  let(:identity) { IdentityLinker.new(user, service_provider).link_identity }
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
            sub: subject_sub,
          },
        },
      },
    }
  end

  let(:subject_sub) { AgencyIdentityLinker.new(identity).link_identity.uuid }
  let(:jwt_headers) { { typ: 'secevent+jwt' } }
  let(:jwt) { JWT.encode(jwt_payload, rp_private_key, 'RS256', jwt_headers) }

  describe '#submit' do
    subject(:submit) { form.submit }

    it 'creates a SecurityEvent record' do
      expect { submit }.to(change { SecurityEvent.count }.by(1))

      security_event = SecurityEvent.last
      aggregate_failures do
        expect(security_event.jti).to eq(jwt_payload[:jti])
        expect(security_event.event_type).to eq(SecurityEvent::AUTHORIZATION_FRAUD_DETECTED)
        expect(security_event.issuer).to eq(service_provider.issuer)
        expect(security_event.user).to eq(user)
      end
    end

    context 'when the event has an occurred_at' do
      let(:occurred_at) { 5.days.ago }
      before do
        jwt_payload[:events].first.last[:occurred_at] = occurred_at.to_i
      end

      it 'saves the occurred_at to the database' do
        submit

        expect(SecurityEvent.last.occurred_at.to_i).to eq(occurred_at.to_i)
      end
    end

    context 'for authorization fraud events' do
      let(:event_type) { SecurityEvent::AUTHORIZATION_FRAUD_DETECTED }

      it 'resets the user password for authorization fraud detected events' do
        expect { submit }.to(change { user.reload.encrypted_password_digest })
      end

      it 'creates a password_invalidated event' do
        expect { submit }.
          to(change { user.events.password_invalidated.size }.from(0).to(1))
      end
    end

    context 'for identity fraud events' do
      let(:event_type) { SecurityEvent::IDENTITY_FRAUD_DETECTED }

      it 'does not reset the user password' do
        expect { submit }.to_not(change { user.reload.encrypted_password_digest })
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

    context 'jti uniqueness' do
      context 'with a jti that has already been recorded for that same user and issuer' do
        before do
          SecurityEvent.create!(
            user: user,
            jti: jti,
            event_type: SecurityEvent::AUTHORIZATION_FRAUD_DETECTED,
            issuer: service_provider.issuer,
          )
        end

        it 'does not create a new record' do
          expect { submit }.to_not(change { SecurityEvent.count })
        end

        it 'reports an error as a duplicate' do
          response = submit

          expect(response.success?).to eq(false)
          expect(form.error_code).to eq('dup')
          expect(form.description).to include('jti was not unique')
        end
      end

      context 'with a jti that has already been recorded for that same user, different issuer' do
        before do
          SecurityEvent.create!(
            user: user,
            jti: jti,
            event_type: SecurityEvent::AUTHORIZATION_FRAUD_DETECTED,
            issuer: 'issuer2',
          )
        end

        it 'creates a record' do
          expect { submit }.to(change { SecurityEvent.count }.by(1))
        end

        it 'reports a success' do
          response = submit

          expect(response.success?).to eq(true)
          expect(form.error_code).to be_nil
          expect(form.description).to be_nil
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
          expect(form.errors[:jwt]).to include('could not parse JWT')
          expect(form.error_code).to eq('jwtParse')
        end
      end

      context 'when signed with a different key than registered to the SP' do
        let(:rp_private_key) do
          OpenSSL::PKey::RSA.new(AppArtifacts.store.oidc_private_key)
        end

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:jwt]).to include('Signature verification failed')
        end
      end

      context 'when the issuer does not have a public key registered' do
        before { service_provider.update(certs: []) }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:jwt]).to include('could not load public key for issuer')
        end
      end

      context 'when signed with an unsupported algorithm' do
        let(:jwt) { JWT.encode(jwt_payload, SecureRandom.hex, 'HS256', jwt_headers) }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:jwt]).to include('unsupported algorithm, must be signed with RS256')
          expect(form.error_code).to eq('jwtCrypto')
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
            to include("invalid aud claim, expected #{api_risc_security_events_url}")
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
          event = jwt_payload[:events].delete(SecurityEvent::AUTHORIZATION_FRAUD_DETECTED)
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
          expect(form.errors[:subject_type]).to include('subject_type must be iss-sub')
        end
      end
    end

    context 'event.subject.sub' do
      context 'with a bad uuid' do
        let(:subject_sub) { 'aaa' }
        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.error_code).to eq('setData')
          expect(form.errors[:sub]).to include('invalid event.subject.sub claim')
        end
      end

      context 'with a uuid for a different identity' do
        let(:subject_sub) { create(:service_provider_identity).uuid }
        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.error_code).to eq('setData')
          expect(form.errors[:sub]).to include('invalid event.subject.sub claim')
        end
      end

      context 'when the service provider has no agency' do
        let(:service_provider) { create(:service_provider, agency: nil, agency_id: nil) }

        it 'is still valid' do
          expect(valid?).to eq(true)
          expect(form.error_code).to eq(nil)
        end
      end
    end

    context 'with a top-level sub claim' do
      before { jwt_payload[:sub] = identity.uuid }

      # https://openid.net/specs/openid-risc-profile-1_0-ID1.html#event-subjects
      it 'is invalid' do
        expect(valid?).to eq(false)
        expect(form.error_code).to eq('setData')
        expect(form.errors[:sub]).to include('top-level sub claim is not accepted')
      end
    end

    context 'with a JWT header typ other than secevent+jwt' do
      before { jwt_headers[:typ] = 'foobar' }

      # https://openid.net/specs/openid-risc-profile-1_0-ID1.html#explicit-typing
      it 'is invalid' do
        expect(valid?).to eq(false)
        expect(form.error_code).to eq('jwtHdr')
        expect(form.errors[:typ]).to include('typ header must be secevent+jwt')
      end
    end

    context 'exp' do
      before { jwt_payload[:exp] = 3.days.ago.to_i }

      # https://openid.net/specs/openid-risc-profile-1_0-ID1.html#exp-claim
      it 'is invalid with an exp claim' do
        expect(valid?).to eq(false)
        expect(form.error_code).to eq('setData')
        expect(form.errors[:exp]).to include('SET events must not have an exp claim')
      end
    end

    context 'jti' do
      context 'without a jti' do
        before { jwt_payload.delete(:jti) }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.error_code).to eq('setData')
          expect(form.errors[:jti]).to include('jti claim is required')
        end
      end
    end
  end
end
