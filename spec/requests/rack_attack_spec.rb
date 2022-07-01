require 'rails_helper'

describe 'throttling requests' do
  before(:all) { Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new }
  before(:each) { Rack::Attack.cache.store.clear }

  let(:requests_per_ip_limit) { IdentityConfig.store.requests_per_ip_limit }
  let(:logins_per_ip_limit) { IdentityConfig.store.logins_per_ip_limit }
  let(:logins_per_email_and_ip_limit) { IdentityConfig.store.logins_per_email_and_ip_limit }

  describe 'safelists' do
    it 'allows all requests from localhost' do
      get '/'

      expect(request.env['rack.attack.throttle_data']).to be_nil
    end
  end

  describe 'high requests per ip' do
    it 'reads the limit and period from ENV vars' do
      get '/', headers: { REMOTE_ADDR: '1.2.3.4' }

      throttle_data = request.env['rack.attack.throttle_data']['req/ip']

      expect(throttle_data[:count]).to eq(1)
      expect(throttle_data[:limit]).to eq(IdentityConfig.store.requests_per_ip_limit)
      expect(throttle_data[:period]).to eq(IdentityConfig.store.requests_per_ip_period)
    end

    context 'when the number of requests is lower than the limit' do
      it 'does not throttle' do
        (requests_per_ip_limit - 1).times do
          get '/', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the request is for an asset' do
      it 'does not throttle' do
        (requests_per_ip_limit + 1).times do
          get '/assets/application.css', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the request is for a pack' do
      it 'does not throttle' do
        pack_url = Dir['public/packs/js/*'].first.gsub(/^public/, '')
        (requests_per_ip_limit + 1).times do
          get pack_url, headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the number of requests is higher than the limit' do
      around do |ex|
        freeze_time { ex.run }
      end

      it 'throttles with a custom response' do
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)
        allow(analytics).to receive(:track_event)

        (requests_per_ip_limit + 1).times do
          get '/', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(429)
        expect(response.body).
          to include('Please wait a few minutes before you try again.')
        expect(response.header['Content-type']).to include('text/html')
        expect(analytics).
          to have_received(:track_event).with('Rate Limit Triggered', type: 'req/ip')
      end

      it 'does not throttle if the path is in the allowlist' do
        allow(IdentityConfig.store).to receive(:requests_per_ip_path_prefixes_allowlist).
          and_return(['/account'])
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)
        allow(analytics).to receive(:track_event)

        (requests_per_ip_limit + 1).times do
          get '/account', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(302)
        expect(response.body).
          to_not include('Please wait a few minutes before you try again.')
        expect(analytics).
          to_not have_received(:track_event).with('Rate Limit Triggered', type: 'req/ip')
      end

      it 'does not throttle if the ip is in the CIDR block allowlist' do
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)
        allow(analytics).to receive(:track_event)

        (requests_per_ip_limit + 1).times do
          get '/', headers: { REMOTE_ADDR: '172.18.100.100' }
        end

        expect(response.status).to eq(200)
        expect(response.body).
          to_not include('Please wait a few minutes before you try again.')
        expect(analytics).
          to_not have_received(:track_event).with('Rate Limit Triggered', type: 'req/ip')
      end
    end

    context 'when the user is signed in' do
      around do |ex|
        freeze_time { ex.run }
      end

      it 'logs the user UUID' do
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)
        allow(analytics).to receive(:track_event)

        user = create(:user, :signed_up)

        post(
          new_user_session_path,
          params: {
            'user[email]' => user.email,
            'user[password]' => user.password,
          },
          headers: { REMOTE_ADDR: '1.2.3.4' },
        )

        requests_per_ip_limit.times do
          get '/account', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(Analytics).to have_received(:new).twice do |arguments|
          expect(arguments[:user]).to eq user
        end
        expect(analytics).
          to have_received(:track_event).with('Rate Limit Triggered', type: 'req/ip')
      end
    end
  end

  describe 'logins per ip' do
    it 'reads the limit and period from ENV vars' do
      post '/', params: { user: { email: 'test@test.com' } }, headers: { REMOTE_ADDR: '1.2.3.4' }

      throttle_data = request.env['rack.attack.throttle_data']['logins/ip']

      expect(throttle_data[:count]).to eq(1)
      expect(throttle_data[:limit]).to eq(IdentityConfig.store.logins_per_ip_limit)
      expect(throttle_data[:period]).to eq(IdentityConfig.store.logins_per_ip_period.seconds)
    end

    context 'when the number of requests is lower than the limit' do
      it 'does not throttle' do
        headers = { REMOTE_ADDR: '1.2.3.4' }
        first_email = 'test1@example.com'
        second_email = 'test2@example.com'

        post '/', params: { user: { email: first_email } }, headers: headers
        post '/', params: { user: { email: second_email } }, headers: headers

        expect(response.status).to eq(200)
      end
    end

    context 'when the request is not a sign in attempt' do
      it 'does not throttle' do
        expect(Rails.logger).to_not receive(:warn)

        (logins_per_ip_limit + 1).times do
          get '/', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the number of logins per ip is higher than the limit per period' do
      around do |ex|
        freeze_time { ex.run }
      end

      it 'throttles with a custom response' do
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)
        allow(analytics).to receive(:track_event)

        headers = { REMOTE_ADDR: '1.2.3.4' }
        first_email = 'test1@example.com'
        second_email = 'test2@example.com'
        third_email = 'test3@example.com'
        fourth_email = 'test4@example.com'

        post '/', params: { user: { email: first_email } }, headers: headers
        post '/', params: { user: { email: second_email } }, headers: headers
        post '/', params: { user: { email: third_email } }, headers: headers
        post '/', params: { user: { email: fourth_email } }, headers: headers

        expect(response.status).to eq(429)
        expect(response.body).
          to include('Please wait a few minutes before you try again.')
        expect(response.header['Content-type']).to include('text/html')
        expect(analytics).
          to have_received(:track_event).with('Rate Limit Triggered', type: 'logins/ip')
      end
    end
  end

  describe 'logins per email and ip' do
    around do |ex|
      freeze_time { ex.run }
    end

    context 'when the number of requests is lower or equal to the limit' do
      it 'does not throttle' do
        (logins_per_email_and_ip_limit - 1).times do
          post '/', params: {
            user: { email: 'test@example.com' },
          }, headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the email is nil, an empty string, or not a String' do
      it 'does not blow up' do
        [nil, '', :xml, 1].each do |email|
          post '/', params: { user: { email: email } }, headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(429)
      end
    end

    context 'when the email is not properly encoded' do
      it 'returns a 400' do
        params = { user: { email: "test@\xFFbar\xF8.com" } }
        post '/', params: params, headers: { REMOTE_ADDR: '1.2.3.4' }

        expect(response.status).to eq(400)
      end
    end

    context 'when number of logins per email + ip is higher than limit per period' do
      it 'throttles with a custom response' do
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)
        allow(analytics).to receive(:track_event)

        (logins_per_email_and_ip_limit + 1).times do |index|
          post '/', params: {
            user: { email: index.even? ? 'test@example.com' : ' test@EXAMPLE.com   ' },
          }, headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        analytics_hash = { type: 'logins/email+ip' }

        expect(response.status).to eq(429)
        expect(response.body).
          to include('Please wait a few minutes before you try again.')
        expect(response.header['Content-type']).to include('text/html')
        expect(analytics).
          to have_received(:track_event).with('Rate Limit Triggered', analytics_hash)
      end
    end

    it 'uses the throttled_response for the blocklisted_response' do
      expect(Rack::Attack.blocklisted_response).to eq Rack::Attack.throttled_response
    end
  end

  describe 'otps per ip' do
    around do |ex|
      freeze_time { ex.run }
    end

    let(:otps_per_ip_limit) { IdentityConfig.store.otps_per_ip_limit }

    context 'when the number of requests is under the limit' do
      it 'does not throttle the request' do
        (otps_per_ip_limit - 1).times do
          get '/otp/send', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(302)
      end
    end

    context 'when the number of requests is over the limit' do
      it 'throttles the request' do
        (otps_per_ip_limit + 1).times do
          get '/otp/send', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(429)
        expect(response.body).
          to include('Please wait a few minutes before you try again.')
        expect(response.header['Content-type']).to include('text/html')
      end
    end
  end

  describe 'phone setups per ip' do
    around do |ex|
      freeze_time { ex.run }
    end

    let(:phone_setups_per_ip_limit) { IdentityConfig.store.phone_setups_per_ip_limit }

    context 'when the number of requests is under the limit' do
      it 'does not throttle the request' do
        (phone_setups_per_ip_limit - 1).times do
          patch '/phone_setup', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(302)
      end
    end

    context 'when the number of requests is over the limit' do
      it 'throttles the request' do
        (phone_setups_per_ip_limit + 1).times do
          patch '/phone_setup', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(429)
        expect(response.body).
          to include('Please wait a few minutes before you try again.')
        expect(response.header['Content-type']).to include('text/html')
      end
    end
  end

  describe '#remote_ip' do
    let(:env) { double 'env' }

    it 'uses ActionDispatch to calculate the IP' do
      expect(env).to receive(:[]).with('action_dispatch.remote_ip').and_return('127.0.0.1')

      Rack::Attack::Request.new(env).remote_ip
    end
  end
end
