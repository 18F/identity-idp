require 'rails_helper'

describe 'throttling requests' do
  before(:all) { Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new }
  before(:each) { Rack::Attack.cache.store.clear }

  describe 'safelists' do
    it 'allows all requests from localhost' do
      get '/'

      expect(request.env['rack.attack.throttle_data']).to be_nil
    end
  end

  describe 'high requests per ip' do
    it 'reads the limit and period from ENV vars' do
      get '/', headers: { REMOTE_ADDR: '1.2.3.4' }

      data = {
        count: 1,
        limit: Figaro.env.requests_per_ip_limit.to_i,
        period: Figaro.env.requests_per_ip_period.to_i.seconds,
      }

      expect(request.env['rack.attack.throttle_data']['req/ip']).to eq(data)
    end

    context 'when the number of requests is lower than the limit' do
      it 'does not throttle' do
        2.times do
          get '/', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the request is for an asset' do
      it 'does not throttle' do
        4.times do
          get '/assets/application.js', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the number of requests is higher than the limit' do
      before do
        allow(Rails.logger).to receive(:warn)

        4.times do
          get '/', headers: { REMOTE_ADDR: '1.2.3.4' }
        end
      end

      it 'throttles' do
        expect(response.status).to eq(429)
      end

      it 'returns a custom body' do
        expect(response.body).
          to include('Your request was denied because of unusual activity.')
      end

      it 'returns text/html for Content-type' do
        expect(response.header['Content-type']).to include('text/html')
      end

      it 'logs the throttle' do
        analytics_hash = {
          event: 'throttle',
          type: 'req/ip',
          user_ip: '1.2.3.4',
          user_uuid: nil,
          visitor_id: request.cookies['ahoy_visitor'],
        }

        expect(Rails.logger).to have_received(:warn).with(analytics_hash.to_json)
      end
    end

    context 'when the user is signed in' do
      it 'logs the user UUID' do
        allow(Rails.logger).to receive(:warn)

        user = create(:user, :signed_up)

        post(
          new_user_session_path,
          params: {
            'user[email]' => user.email,
            'user[password]' => user.password,
          }
        )

        4.times do
          get '/account', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        analytics_hash = {
          event: 'throttle',
          type: 'req/ip',
          user_ip: '1.2.3.4',
          user_uuid: user.uuid,
          visitor_id: request.cookies['ahoy_visitor'],
        }

        expect(Rails.logger).to have_received(:warn).with(analytics_hash.to_json)
      end
    end
  end

  describe 'logins per ip' do
    it 'reads the limit and period from ENV vars' do
      post '/', params: { user: { email: 'test@test.com' } }, headers: { REMOTE_ADDR: '1.2.3.4' }

      data = {
        count: 1,
        limit: Figaro.env.logins_per_ip_limit.to_i,
        period: Figaro.env.logins_per_ip_period.to_i.seconds,
      }

      expect(request.env['rack.attack.throttle_data']['logins/ip']).to eq(data)
    end

    context 'when the number of requests is lower than the limit' do
      it 'does not throttle' do
        2.times do
          post '/', params: {
            user: { email: 'test@example.com' },
          }, headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the request is not a sign in attempt' do
      it 'does not throttle' do
        expect(Rails.logger).to_not receive(:warn)

        3.times do
          get '/', headers: { REMOTE_ADDR: '1.2.3.4' }
        end

        expect(response.status).to eq(200)
      end
    end

    context 'when the number of logins per ip is higher than the limit per period' do
      before do
        allow(Rails.logger).to receive(:warn)

        3.times do
          post '/', params: {
            user: { email: 'test@example.com' },
          }, headers: { REMOTE_ADDR: '1.2.3.4' }
        end
      end

      it 'throttles' do
        expect(response.status).to eq(429)
      end

      it 'returns a custom body' do
        expect(response.body).
          to include('Your request was denied because of unusual activity.')
      end

      it 'returns text/html for Content-type' do
        expect(response.header['Content-type']).to include('text/html')
      end

      it 'logs the throttle' do
        analytics_hash = {
          event: 'throttle',
          type: 'logins/ip',
          user_ip: '1.2.3.4',
          user_uuid: nil,
          visitor_id: request.cookies['ahoy_visitor'],
        }

        expect(Rails.logger).to have_received(:warn).with(analytics_hash.to_json)
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
