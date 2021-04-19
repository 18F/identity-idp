require 'rails_helper'

RSpec.describe PushNotification::HttpPush do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }

  let(:sp_with_push_url) { create(:service_provider, push_notification_url: 'http://foo.bar/push') }
  let(:sp_no_push_url) { create(:service_provider, push_notification_url: nil) }

  let!(:sp_with_push_url_identity) do
    IdentityLinker.new(user, sp_with_push_url.issuer).link_identity
  end
  let!(:sp_no_push_url_identity) do
    IdentityLinker.new(user, sp_no_push_url.issuer).link_identity
  end

  let(:event) do
    PushNotification::IdentifierRecycledEvent.new(
      user: user,
      email: Faker::Internet.safe_email,
    )
  end
  let(:now) { Time.zone.now }
  let(:risc_notifications_eventbridge_enabled) { false }
  let(:push_notifications_enabled) { true }
  let(:eventbridge_client) { Aws::EventBridge::Client.new(stub_responses: true) }

  subject(:http_push) { PushNotification::HttpPush.new(event, now: now) }

  before do
    allow(IdentityConfig.store).to receive(:risc_notifications_eventbridge_enabled).
      and_return(risc_notifications_eventbridge_enabled)
    allow(Identity::Hostdata).to receive(:env).and_return('dev')
    allow(IdentityConfig.store).to receive(:push_notifications_enabled).
      and_return(push_notifications_enabled)

    allow(http_push).to receive(:eventbridge_client).and_return(eventbridge_client)
  end

  describe '#deliver' do
    subject(:deliver) { http_push.deliver }

    context 'when push_notifications_enabled is disabled' do
      let(:push_notifications_enabled) { false }

      it 'does not deliver any notifications' do
        expect(http_push).to_not receive(:deliver_one)

        deliver
      end
    end

    context 'when the EventBridge is disabled' do
      let(:risc_notifications_eventbridge_enabled) { false }

      it 'makes an HTTP post to service providers with a push_notification_url' do
        stub_request(:post, sp_with_push_url.push_notification_url).
          with do |request|
            expect(request.headers['Content-Type']).to eq('application/secevent+jwt')
            expect(request.headers['Accept']).to eq('application/json')

            payload, headers = JWT.decode(
              request.body,
              AppArtifacts.store.oidc_public_key,
              true,
              algorithm: 'RS256',
            )

            expect(headers['typ']).to eq('secevent+jwt')

            expect(payload['iss']).to eq(root_url)
            expect(payload['iat']).to eq(now.to_i)
            expect(payload['exp']).to eq((now + 12.hours).to_i)
            expect(payload['aud']).to eq(sp_with_push_url.push_notification_url)
            expect(payload['events']).to eq(event.event_type => event.payload.as_json)
          end

        deliver
      end
    end

    context 'when the EventBridge is enabled' do
      let(:risc_notifications_eventbridge_enabled) { true }

      it 'posts to the EventBridge' do
        expect(eventbridge_client).to receive(:put_events).and_wrap_original do |impl, entries:|
          expect(entries.size).to eq(1)
          entry = entries.first

          expect(entry[:time]).to eq(now)
          expect(entry[:source]).to eq(sp_with_push_url.issuer)
          expect(entry[:event_bus_name]).to eq('dev-risc-notifications')
          expect(entry[:detail_type]).to eq('notification')

          payload, headers = JWT.decode(
            entry[:detail],
            AppArtifacts.store.oidc_public_key,
            true,
            algorithm: 'RS256',
          )

          expect(headers['typ']).to eq('secevent+jwt')

          expect(payload['iss']).to eq(root_url)
          expect(payload['iat']).to eq(now.to_i)
          expect(payload['exp']).to eq((now + 12.hours).to_i)
          expect(payload['aud']).to eq(sp_with_push_url.push_notification_url)
          expect(payload['events']).to eq(event.event_type => event.payload.as_json)

          impl.call(entries: entries)
        end

        deliver
      end
    end

    context 'with an event that sends agency-specific iss_sub' do
      let(:event) { PushNotification::AccountPurgedEvent.new(user: user) }

      let(:agency_uuid) { AgencyIdentityLinker.new(sp_with_push_url_identity).link_identity.uuid }

      context 'when the EventBridge is disabled' do
        let(:risc_notifications_eventbridge_enabled) { false }

        it 'sends the agency-specific uuid' do
          stub_request(:post, sp_with_push_url.push_notification_url).
            with do |request|
              payload, _headers = JWT.decode(
                request.body,
                AppArtifacts.store.oidc_public_key,
                true,
                algorithm: 'RS256',
              )

              expect(payload['events'][event.event_type]['subject']['sub']).to eq(agency_uuid)
            end

          deliver
        end
      end

      context 'when the EventBridge is enabled' do
        let(:risc_notifications_eventbridge_enabled) { true }

        it 'sends the agency-specific uuid' do
          expect(eventbridge_client).to receive(:put_events) do |entries:|
            expect(entries.size).to eq(1)
            entry = entries.first

            payload, _headers = JWT.decode(
              entry[:detail],
              AppArtifacts.store.oidc_public_key,
              true,
              algorithm: 'RS256',
            )

            expect(payload['events'][event.event_type]['subject']['sub']).to eq(agency_uuid)
          end

          deliver
        end
      end
    end

    context 'with a timeout when posting to one url' do
      let(:third_sp) { create(:service_provider, push_notification_url: 'http://sp.url/push') }

      before do
        IdentityLinker.new(user, third_sp.issuer).link_identity

        stub_request(:post, sp_with_push_url.push_notification_url).to_timeout
        stub_request(:post, third_sp.push_notification_url).to_return(status: 200)
      end

      it 'still posts to the others' do
        deliver

        expect(WebMock).to have_requested(:post, third_sp.push_notification_url)
      end

      it 'notifies NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).
          with(instance_of(Faraday::ConnectionFailed))

        deliver
      end
    end

    context 'with a non-200 response from a push notification url' do
      before do
        stub_request(:post, sp_with_push_url.push_notification_url).
          to_return(status: 500)
      end

      it 'notifies NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).
          with(instance_of(PushNotification::PushNotificationError))

        deliver
      end
    end

    context 'when a user has revoked access to an SP' do
      before do
        identity = user.identities.find_by(service_provider: sp_with_push_url.issuer)
        RevokeServiceProviderConsent.new(identity).call
      end

      context 'when the EventBridge is disabled' do
        let(:risc_notifications_eventbridge_enabled) { false }

        it 'does not notify that SP' do
          deliver

          expect(WebMock).not_to have_requested(:get, sp_with_push_url.push_notification_url)
        end
      end

      context 'when the EventBridge is enabled' do
        let(:risc_notifications_eventbridge_enabled) { true }

        it 'does not notify that SP' do
          expect(eventbridge_client).to_not receive(:put_events)

          deliver
        end
      end
    end
  end
end
