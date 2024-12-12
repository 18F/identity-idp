require 'rails_helper'

RSpec.describe PushNotification::HttpPush do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }

  let(:sp_with_push_url) { create(:service_provider, active: true, push_notification_url: 'http://foo.bar/push') }
  let(:sp_no_push_url) { create(:service_provider, active: true, push_notification_url: nil) }

  let!(:sp_with_push_url_identity) do
    IdentityLinker.new(user, sp_with_push_url).link_identity
  end
  let!(:sp_no_push_url_identity) do
    IdentityLinker.new(user, sp_no_push_url).link_identity
  end

  let(:event) do
    PushNotification::IdentifierRecycledEvent.new(
      user: user,
      email: Faker::Internet.email,
    )
  end
  let(:now) { Time.zone.now }
  let(:push_notifications_enabled) { true }

  subject(:http_push) { PushNotification::HttpPush.new(event, now: now) }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Identity::Hostdata).to receive(:env).and_return('dev')
    allow(IdentityConfig.store).to receive(:push_notifications_enabled)
      .and_return(push_notifications_enabled)
  end

  describe '#deliver' do
    subject(:deliver) { http_push.deliver }

    it 'enqueues a background job to deliver a notification' do
      expect { deliver }.to have_enqueued_job(RiscDeliveryJob).once
    end

    it 'enqueues a background job with the correct arguments' do
      expect { deliver }.to have_enqueued_job(RiscDeliveryJob).with { |args|
        expect(args[:push_notification_url]).to eq sp_with_push_url.push_notification_url
        expect(args[:event_type]).to eq event.event_type
        expect(args[:issuer]).to eq sp_with_push_url.issuer

        jwt_payload, headers = JWT.decode(
          args[:jwt],
          Rails.application.config.oidc_public_key,
          true,
          algorithm: 'RS256',
          kid: JWT::JWK.new(AppArtifacts.store.oidc_primary_private_key).kid,
        )

        expect(headers['typ']).to eq('secevent+jwt')
        expect(headers['kid']).to eq(JWT::JWK.new(AppArtifacts.store.oidc_primary_private_key).kid)

        expect(jwt_payload['iss']).to eq(root_url)
        expect(jwt_payload['iat']).to eq(now.to_i)
        expect(jwt_payload['exp']).to eq((now + 12.hours).to_i)
        expect(jwt_payload['aud']).to eq(sp_with_push_url.push_notification_url)
        expect(jwt_payload['events']).to eq(event.event_type => event.payload.as_json)
      }
    end

    context 'when push_notifications_enabled is false' do
      let(:push_notifications_enabled) { false }

      it 'does not enqueue a RISC notification' do
        expect { deliver }.not_to have_enqueued_job(RiscDeliveryJob)
      end
    end

    context 'with an event that sends agency-specific iss_sub' do
      let(:event) { PushNotification::AccountPurgedEvent.new(user: user) }

      let(:agency_uuid) { AgencyIdentityLinker.new(sp_with_push_url_identity).link_identity.uuid }

      it 'sends the agency-specific uuid' do
        expect { deliver }.to have_enqueued_job(RiscDeliveryJob).with { |args|
          jwt_payload, _headers = JWT.decode(
            args[:jwt],
            Rails.application.config.oidc_public_key,
            true,
            algorithm: 'RS256',
            kid: JWT::JWK.new(AppArtifacts.store.oidc_primary_private_key).kid,
          )
          expect(jwt_payload['events'][event.event_type]['subject']['sub']).to eq(agency_uuid)
        }
      end
    end

    context 'when a service provider is no longer active' do
      before { sp_with_push_url.update!(active: false) }

      it 'does not enqueue a RISC notification' do
        expect { deliver }.not_to have_enqueued_job(RiscDeliveryJob)
      end
    end

    context 'when a user has revoked access to a service provider' do
      before do
        identity = user.identities.find_by(service_provider: sp_with_push_url.issuer)
        RevokeServiceProviderConsent.new(identity).call
      end

      it 'does not enqueue a RISC notification' do
        expect { deliver }.not_to have_enqueued_job(RiscDeliveryJob)
      end
    end
  end
end
