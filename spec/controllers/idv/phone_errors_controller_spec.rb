require 'rails_helper'

RSpec.describe Idv::PhoneErrorsController do
  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    allow(subject).to receive(:remaining_attempts).and_return(5)
    stub_analytics
    allow(@analytics).to receive(:track_event)
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)

    if user
      stub_sign_in(user)
      subject.idv_session.user_phone_confirmation = false
      subject.idv_session.previous_phone_step_params = previous_phone_step_params
    end
  end

  shared_examples_for 'an idv phone errors controller action' do
    describe 'before_actions' do
      it 'includes before_actions from IdvSession' do
        expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
      end
    end

    context 'authenticated user' do
      let(:user) { create(:user) }

      context 'the user has not submtted a phone number' do
        it 'redirects to phone step' do
          subject.idv_session.previous_phone_step_params = nil
          get action

          expect(response).to redirect_to(idv_phone_url)
        end
      end

      context 'with already submitted phone number' do
        context 'the user has not confirmed their phone' do
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
              expect(@analytics).not_to receive(:track_event).with(
                'IdV: phone error visited',
                anything,
              )
              get action
            end
          end
        end

        context 'the user has confirmed their phone' do
          before do
            subject.idv_session.user_phone_confirmation = true
          end

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
      end
    end

    context 'the user is not authenticated' do
      let(:user) { nil }
      it 'redirects to sign in' do
        get action

        expect(response).to redirect_to(new_user_session_url)
      end
    end
  end

  let(:user) { nil }
  let(:phone) { '3602345678' }
  let(:country_code) { 'US' }
  let(:previous_phone_step_params) do
    {
      phone: phone,
      international_code: country_code,
    }
  end

  describe '#warning' do
    let(:action) { :warning }
    let(:template) { 'idv/phone_errors/warning' }
    let(:user) { create(:user) }

    it_behaves_like 'an idv phone errors controller action'

    context 'with rate limit attempts' do
      before do
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment!
      end

      it 'assigns phone' do
        get action
        expect(assigns(:phone)).to eql(phone)
      end

      it 'assigns country_code' do
        get action
        expect(assigns(:country_code)).to eql(country_code)
      end

      context 'not knowing about a phone just entered' do
        it 'does not crash' do
          subject.idv_session.previous_phone_step_params = nil
          get action
        end
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
          **ab_test_args,
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
          **ab_test_args,
        )
      end
    end
  end

  describe '#failure' do
    let(:action) { :failure }

    context 'while rate limited' do
      let(:user) { create(:user) }

      it 'renders an error and assigns expiration time' do
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment_to_limited!
        get action

        expect(assigns(:expires_at)).to be_kind_of(Time)
        expect(response).to render_template('idv/phone_errors/failure')
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
            limiter_expires_at: attempted_at + rate_limit_window,
            **ab_test_args,
          )
        end
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
          expect(@analytics).not_to receive(:track_event).with(
            'IdV: phone error visited',
            anything,
          )
          get action
        end
      end
    end

    context 'while not rate limited' do
      let(:user) { create(:user) }

      it 'redirects to the phone step' do
        get action

        expect(response).to redirect_to(idv_phone_url)
      end
    end

    context 'the user is not authenticated' do
      let(:user) { nil }
      it 'redirects to sign in' do
        get action

        expect(response).to redirect_to(new_user_session_url)
      end
    end
  end
end
