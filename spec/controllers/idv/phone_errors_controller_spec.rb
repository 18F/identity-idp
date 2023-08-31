require 'rails_helper'

RSpec.describe Idv::PhoneErrorsController do
  shared_examples_for 'an idv phone errors controller action' do
    describe 'before_actions' do
      it 'includes before_actions from IdvSession' do
        expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
      end
    end

    context 'the user is authenticated and has not confirmed their phone' do
      let(:user) { create(:user) }

      it 'renders the error' do
        get action

        expect(response).to render_template(template)
      end

      it 'logs an event' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: phone error visited',
          hash_including(
            type: action,
          ),
        )
        get action
      end

      context 'fetch() request from form-steps-wait JS' do
        before do
          request.headers['X-Form-Steps-Wait'] = '1'
        end
        it 'returns an empty response' do
          get action
          expect(response).to have_http_status(204)
        end
        it 'does not log an event' do
          expect(@analytics).not_to receive(:track_event).with('IdV: phone error visited', anything)
          get action
        end
      end
    end

    context 'the user is authenticated and has confirmed their phone' do
      let(:user) { create(:user) }
      let(:idv_session_user_phone_confirmation) { true }

      it 'redirects to the review url' do
        get action

        expect(response).to redirect_to(idv_review_url)
      end
      it 'does not log an event' do
        expect(@analytics).not_to receive(:track_event).with(
          'IdV: phone error visited',
          hash_including(
            type: action,
          ),
        )
        get action
      end
    end

    context 'the user is not authenticated and not recovering their account' do
      let(:user) { nil }
      it 'redirects to sign in' do
        get action

        expect(response).to redirect_to(new_user_session_url)
      end
      it 'does not log an event' do
        expect(@analytics).not_to receive(:track_event).with(
          'IdV: phone error visited',
          hash_including(
            type: action,
          ),
        )
        get action
      end
    end
  end

  let(:idv_session) { double }
  let(:idv_session_user_phone_confirmation) { false }
  let(:user) { nil }
  let(:phone) { '3602345678' }
  let(:country_code) { 'US' }
  let(:previous_phone_step_params) do
    {
      phone: phone,
      international_code: country_code,
    }
  end

  before do
    allow(idv_session).to receive(:user_phone_confirmation).
      and_return(idv_session_user_phone_confirmation)
    allow(idv_session).to receive(:current_user).and_return(user)
    allow(idv_session).to receive(:previous_phone_step_params).
      and_return(previous_phone_step_params)
    allow(subject).to receive(:remaining_attempts).and_return(5)
    allow(controller).to receive(:idv_session).and_return(idv_session)
    stub_sign_in(user) if user

    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe '#warning' do
    let(:action) { :warning }
    let(:template) { 'idv/phone_errors/warning' }
    let(:user) { create(:user) }

    it_behaves_like 'an idv phone errors controller action'

    it 'assigns phone' do
      get action
      expect(assigns(:phone)).to eql(phone)
    end

    it 'assigns country_code' do
      get action
      expect(assigns(:country_code)).to eql(country_code)
    end

    context 'not knowing about a phone just entered' do
      let(:previous_phone_step_params) { nil }
      it 'does not crash' do
        get action
      end
    end

    context 'with rate limit attempts' do
      before do
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment!
      end

      it 'assigns remaining count' do
        get action

        expect(assigns(:remaining_attempts)).to be_kind_of(Numeric)
      end

      it 'logs an event' do
        get action

        expect(@analytics).to have_received(:track_event).with(
          'IdV: phone error visited',
          type: action,
          remaining_attempts: 4,
        )
      end
    end
  end

  describe '#timeout' do
    let(:action) { :timeout }
    let(:template) { 'idv/phone_errors/timeout' }

    it_behaves_like 'an idv phone errors controller action'

    context 'with rate limit attempts' do
      let(:user) { create(:user) }

      before do
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment!
      end

      it 'assigns remaining count' do
        get action

        expect(assigns(:remaining_step_attempts)).to be_kind_of(Numeric)
      end
    end
  end

  describe '#jobfail' do
    let(:action) { :jobfail }
    let(:template) { 'idv/phone_errors/jobfail' }

    it_behaves_like 'an idv phone errors controller action'

    context 'with rate limit attempts' do
      let(:user) { create(:user) }

      before do
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment!
      end

      it 'assigns remaining count' do
        get action

        expect(assigns(:remaining_attempts)).to be_kind_of(Numeric)
      end

      it 'logs an event' do
        get action

        expect(@analytics).to have_received(:track_event).with(
          'IdV: phone error visited',
          type: action,
          remaining_attempts: 4,
        )
      end
    end
  end

  describe '#failure' do
    let(:action) { :failure }
    let(:template) { 'idv/phone_errors/failure' }

    it_behaves_like 'an idv phone errors controller action'

    context 'while rate limited' do
      let(:user) { create(:user) }

      it 'assigns expiration time' do
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment_to_limited!
        get action

        expect(assigns(:expires_at)).to be_kind_of(Time)
      end

      it 'logs an event' do
        freeze_time do
          attempted_at = Time.zone.now.utc
          RateLimiter.new(rate_limit_type: :proof_address, user: user).increment_to_limited!
          rate_limit_window = RateLimiter.attempt_window_in_minutes(:proof_address).minutes

          get action

          expect(@analytics).to have_received(:track_event).with(
            'IdV: phone error visited',
            type: action,
            throttle_expires_at: attempted_at + rate_limit_window,
          )
        end
      end
    end
  end
end
