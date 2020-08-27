require 'spec_helper'

RSpec.describe PushNotification::HttpPush do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }

  let(:sp_with_push_url) { create(:service_provider, push_notification_url: 'http://foo.bar/push') }
  let(:sp_no_push_url) { create(:service_provider, push_notification_url: nil) }

  before do
    IdentityLinker.new(user, sp_with_push_url.issuer).link_identity
    IdentityLinker.new(user, sp_no_push_url.issuer).link_identity
  end

  let(:event) do
    PushNotification::IdentifierRecycledEvent.new(
      user: user,
      email: Faker::Internet.safe_email,
    )
  end
  let(:now) { Time.zone.now }

  subject(:http_push) { PushNotification::HttpPush.new(event, now: now) }

  describe '#deliver' do
    subject(:deliver) { http_push.deliver }

    it 'makes an HTTP post to service providers with a push_notification_url' do
      stub_request(:post, sp_with_push_url.push_notification_url).
        with do |request|
          expect(request.headers['Content-Type']).to eq('application/secevent+jwt')
          expect(request.headers['Accept']).to eq('application/json')

          payload, headers = JWT.decode(
            request.body,
            RequestKeyManager.public_key,
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

      it 'does not notify that SP' do
        deliver

        expect(WebMock).not_to have_requested(:get, sp_with_push_url.push_notification_url)
      end
    end
  end
end
