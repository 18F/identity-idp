require 'rails_helper'

describe 'throttling requests' do
  include Rack::Test::Methods

  def app
    Rails.application
  end

  describe 'whitelists' do
    it 'allows all requests from localhost' do
      get '/'

      expect(last_request.env['rack.attack.throttle_data']).to be_nil
    end
  end

  describe 'high requests per ip' do
    it 'reads the limit and period from ENV vars' do
      get '/', {}, 'REMOTE_ADDR' => '1.2.3.4'

      data = {
        count: 1,
        limit: Figaro.env.requests_per_ip_limit.to_i,
        period: Figaro.env.requests_per_ip_period.to_i.seconds
      }

      expect(last_request.env['rack.attack.throttle_data']['req/ip']).to eq(data)
    end

    context 'when the number of requests is lower than the limit' do
      it 'does not throttle' do
        2.times do
          get '/', {}, 'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
        end

        expect(last_response.status).to_not eq(429)
      end
    end

    context 'when the request is for an asset' do
      it 'does not throttle' do
        4.times do
          get '/assets/application.js', {}, 'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
        end

        expect(last_response.status).to_not eq(429)
      end
    end

    context 'when the number of requests is higher than the limit' do
      before do
        allow(Rails.logger).to receive(:warn)

        4.times do
          get '/', {}, 'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
        end
      end

      it 'throttles' do
        expect(last_response.status).to eq(429)
      end

      it 'returns a custom body' do
        expect(last_response.body).
          to include('Your request was denied because of unusual activity.')
      end

      it 'returns text/html for Content-type' do
        expect(last_response.header['Content-type']).to include('text/html')
      end

      it 'logs the throttle' do
        expect(Rails.logger).to have_received(:warn).
          with('req/ip throttle occurred for 1.2.3.4')
      end
    end
  end

  describe 'logins per ip' do
    it 'reads the limit and period from ENV vars' do
      post '/', { user: { email: 'test@example.com' } }, 'REMOTE_ADDR' => '1.2.3.4'

      data = {
        count: 1,
        limit: Figaro.env.logins_per_ip_limit.to_i,
        period: Figaro.env.logins_per_ip_period.to_i.seconds
      }

      expect(last_request.env['rack.attack.throttle_data']['logins/ip/level_1']).to eq(data)
    end

    it 'uses an exponential backoff' do
      3.times do
        post '/', { user: { email: 'test@example.com' } }, 'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
        Timecop.travel(120.seconds)
      end

      (1..5).each do |level|
        expect(last_request.env['rack.attack.throttle_data']["logins/ip/level_#{level}"][:period]).
          to eq(Figaro.env.logins_per_ip_period.to_i**level)
      end

      (1..5).each do |level|
        expect(last_request.env['rack.attack.throttle_data']["logins/ip/level_#{level}"][:limit]).
          to eq(Figaro.env.logins_per_ip_limit.to_i * level)
      end

      Timecop.return
    end

    context 'when the number of requests is lower than the limit' do
      it 'does not throttle' do
        2.times do
          post '/', { user: { email: 'test@example.com' } }, 'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
        end

        expect(last_response.status).to_not eq(429)
      end
    end

    context 'when the request is not a sign in attempt' do
      it 'does not throttle' do
        expect(Rails.logger).to_not receive(:warn).
          with('logins/ip/level_1 throttle occurred for 1.2.3.4')

        3.times do
          get '/', {}, 'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
        end
      end
    end

    context 'when the number of logins per ip is higher than the limit per period' do
      before do
        allow(Rails.logger).to receive(:warn)

        3.times do
          post '/', { user: { email: 'test@example.com' } }, 'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
        end
      end

      it 'throttles' do
        expect(last_response.status).to eq(429)
      end

      it 'returns a custom body' do
        expect(last_response.body).
          to include('Your request was denied because of unusual activity.')
      end

      it 'returns text/html for Content-type' do
        expect(last_response.header['Content-type']).to include('text/html')
      end

      it 'logs the throttle' do
        expect(Rails.logger).to have_received(:warn).
          with('logins/ip/level_1 throttle occurred for 1.2.3.4')
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

  describe 'OTP delivery blocklist' do
    it 'blocks the user for bantime after maxretry OTP requests within findtime period' do
      allow(Figaro.env).to receive(:requests_per_ip_limit).and_return('300')
      allow(Rails.logger).to receive(:warn)

      user = create(:user, :signed_up, phone: '+1 (202) 555-0100')
      second_user_with_same_number = create(:user, :signed_up, phone: '+1 (202) 555-0100')

      # sign in with first user and have them trigger the throttle
      post(
        new_user_session_path,
        'user[email]' => user.email,
        'user[password]' => user.password
      )

      3.times do
        get(
          '/otp/send',
          { otp_delivery_selection_form: { otp_method: 'sms' } },
          'REMOTE_ADDR' => '1.2.3.4'
        )
      end

      expect(last_response.status).to eq(429)
      expect(Rails.logger).to have_received(:warn).
        with("OTP delivery throttle occurred for #{user.uuid}")

      delete destroy_user_session_path

      # sign in with second user, and make sure they are blocked on the first
      # attempt since they have the same number and the throttling is based
      # on the phone number
      post(
        new_user_session_path,
        'user[email]' => second_user_with_same_number.email,
        'user[password]' => second_user_with_same_number.password
      )

      get(
        '/otp/send',
        { otp_delivery_selection_form: { otp_method: 'sms' } },
        'REMOTE_ADDR' => '1.2.3.5'
      )

      expect(last_response.status).to eq(429)
      expect(Rails.logger).to have_received(:warn).
        with("OTP delivery throttle occurred for #{second_user_with_same_number.uuid}")
    end

    it 'uses the throttled_response for the blocklisted_response' do
      expect(Rack::Attack.blocklisted_response).to eq Rack::Attack.throttled_response
    end
  end
end
