require 'rails_helper'

RSpec.describe Api::Internal::SessionsController do
  let(:user) { nil }

  around do |example|
    freeze_time { example.run }
  end

  before do
    stub_analytics
    establish_warden_session if user
  end

  describe '#show' do
    subject(:response) { JSON.parse(get(:show).body, symbolize_names: true) }

    it 'responds with live and timeout properties' do
      expect(response).to eq(live: false, timeout: nil)
    end

    context 'signed in' do
      let(:user) { create(:user, :fully_registered) }

      it 'responds with live and timeout properties' do
        expect(response).to eq(live: true, timeout: User.timeout_in.from_now.as_json)
      end

      context 'after a delay' do
        let(:delay) { 0.seconds }

        before { travel_to delay.from_now }

        context 'after a delay prior to session timeout' do
          let(:delay) { User.timeout_in - 1.second }

          it 'responds with live and timeout properties' do
            expect(response).to eq(
              live: true,
              timeout: (User.timeout_in - delay).from_now.as_json,
            )
          end
        end

        context 'after a delay exceeding session timeout' do
          let(:delay) { User.timeout_in + 1.second }

          it 'responds with live and timeout properties' do
            expect(response).to eq(live: false, timeout: nil)
          end
        end
      end

      context 'when a request extends session timeout' do
        let(:future_time) { (User.timeout_in - 1.second).from_now }

        before do
          travel_to future_time
          # Ideally we could repeat the behavior from `establish_warden_session`, but the request
          # and controller persist between simulated request calls.
          session['warden.user.user.session']['last_request_at'] = future_time.to_i
        end

        it 'responds with live and timeout properties' do
          expect(response).to eq(live: true, timeout: (future_time + User.timeout_in).as_json)
        end
      end
    end
  end

  describe '#update' do
    let(:response) { put(:update) }
    subject(:response_body) { JSON.parse(response.body, symbolize_names: true) }

    it 'responds with live and timeout properties' do
      expect(response_body).to eq(live: false, timeout: nil)
    end

    it 'includes csrf token in the response headers' do
      expect(response.headers['X-CSRF-Token']).to be_kind_of(String)
    end

    it 'does not track analytics event' do
      response

      expect(@analytics).not_to have_logged_event('Session Kept Alive')
    end

    context 'signed in' do
      let(:user) { create(:user, :fully_registered) }

      it 'responds with live and timeout properties' do
        expect(response_body).to eq(live: true, timeout: User.timeout_in.from_now.as_json)
      end

      it 'tracks analytics event' do
        response

        expect(@analytics).to have_logged_event('Session Kept Alive')
      end

      context 'after a delay' do
        let(:delay) { 0.seconds }

        before { travel_to delay.from_now }

        context 'after a delay prior to session timeout' do
          let(:delay) { User.timeout_in - 1.second }

          it 'updates timeout and responds with live and timeout properties' do
            expect(response_body).to eq(live: true, timeout: User.timeout_in.from_now.as_json)
          end

          it 'tracks analytics event' do
            response

            expect(@analytics).to have_logged_event('Session Kept Alive')
          end
        end

        context 'after a delay exceeding session timeout' do
          let(:delay) { User.timeout_in + 1.second }

          it 'responds with live and timeout properties' do
            expect(response_body).to eq(live: false, timeout: nil)
          end

          it 'does not track analytics event' do
            response

            expect(@analytics).not_to have_logged_event('Session Kept Alive')
          end
        end
      end
    end
  end

  def establish_warden_session
    sign_in(user)

    # Relevant timeout session values are stored on request, but the API controller itself skips
    # these so as not to affect the planned timeout. Send a request to some other controller to
    # establish the session values.
    original_controller = @controller
    @controller = AccountsController.new
    get :show
    @controller = original_controller
  end
end
