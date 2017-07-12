require 'rails_helper'

describe SignUp::EmailConfirmationsController do
  describe '#create' do
    before do
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    it 'tracks nil email confirmation token' do
      analytics_hash = {
        success: false,
        errors: { confirmation_token: [t('errors.messages.blank')] },
        user_id: nil,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: nil

      expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      expect(response).to redirect_to sign_up_email_resend_path
    end

    it 'tracks blank email confirmation token' do
      analytics_hash = {
        success: false,
        errors: { confirmation_token: [t('errors.messages.blank')] },
        user_id: nil,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: ''

      expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      expect(response).to redirect_to sign_up_email_resend_path
    end

    it 'tracks confirmation token as a single-quoted empty string' do
      analytics_hash = {
        success: false,
        errors: { confirmation_token: [t('errors.messages.invalid')] },
        user_id: nil,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: "''"

      expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      expect(response).to redirect_to sign_up_email_resend_path
    end

    it 'tracks confirmation token as a double-quoted empty string' do
      analytics_hash = {
        success: false,
        errors: { confirmation_token: [t('errors.messages.invalid')] },
        user_id: nil,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: '""'

      expect(flash[:error]).to eq t('errors.messages.confirmation_invalid_token')
      expect(response).to redirect_to sign_up_email_resend_path
    end

    it 'tracks already confirmed token' do
      user = create(:user, confirmation_token: 'foo')

      analytics_hash = {
        success: false,
        errors: { email: [t('errors.messages.already_confirmed')] },
        user_id: user.uuid,
        existing_user: true,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: 'foo'
    end

    it 'tracks expired token' do
      user = create(:user, :unconfirmed)
      UpdateUser.new(
        user: user,
        attributes: { confirmation_token: 'foo', confirmation_sent_at: Time.zone.now - 2.days }
      ).call

      analytics_hash = {
        success: false,
        errors: { confirmation_token: [t('errors.messages.expired')] },
        user_id: user.uuid,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: 'foo'

      expect(flash[:error]).
        to eq t('errors.messages.confirmation_period_expired', period: '24 hours')
      expect(response).to redirect_to sign_up_email_resend_path
    end

    context '_request_id' do
      let(:confirmation_token) { SecureRandom.uuid }
      let!(:user) { create(:user, :unconfirmed, confirmation_token: confirmation_token) }

      subject(:action) do
        get :create, confirmation_token: confirmation_token, _request_id: _request_id
      end

      context 'with a valid _request_id' do
        let(:service_provider_request) do
          create(:service_provider_request, uuid: SecureRandom.uuid)
        end
        let(:_request_id) { service_provider_request.uuid }

        it 'redirects with the request_id' do
          action

          destination = sign_up_enter_password_url(
            request_id: _request_id,
            confirmation_token: confirmation_token
          )

          expect(response).to redirect_to(destination)
        end

        it 'tracks an en event with request_id_present' do
          analytics_hash = {
            success: true,
            errors: {},
            request_id_present: true,
          }

          expect(@analytics).to receive(:track_event).
            with(Analytics::EMAIL_CONFIRMATION_REQUEST_ID, analytics_hash)

          action
        end
      end

      context 'without a _request_id' do
        let(:_request_id) { nil }

        it 'redirects with a blank request_id' do
          action

          destination = sign_up_enter_password_url(
            request_id: '',
            confirmation_token: confirmation_token
          )

          expect(response).to be_redirect
          params = URIService.params(response.location)
          expect(params[:request_id]).to be_blank
        end

        it 'tracks an en event with no request_id_present' do
          analytics_hash = {
            success: true,
            errors: {},
            request_id_present: false,
          }

          expect(@analytics).to receive(:track_event).
            with(Analytics::EMAIL_CONFIRMATION_REQUEST_ID, analytics_hash)

          action
        end
      end

      context 'with an invalid _request_id' do
        let(:_request_id) { 'aaa' }

        it 'renders an error' do
          action

          expect(flash[:error]).to eq(t('errors.messages.request_id_invalid'))
        end

        it 'tracks an error' do
          analytics_hash = {
            success: false,
            errors: { request_id: ['is invalid'] },
            request_id_present: true,
          }

          expect(@analytics).to receive(:track_event).
            with(Analytics::EMAIL_CONFIRMATION_REQUEST_ID, analytics_hash)

          action
        end
      end
    end
  end

  describe 'Valid email confirmation tokens' do
    it 'tracks a valid email confirmation token event' do
      user = create(:user, :unconfirmed, confirmation_token: 'foo')

      stub_analytics
      allow(@analytics).to receive(:track_event)

      analytics_hash = {
        success: true,
        errors: {},
        user_id: user.uuid,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: 'foo'
    end
  end

  describe 'User confirms new email' do
    it 'tracks the event' do
      user = create(
        :user,
        :signed_up,
        confirmation_token: 'foo',
        confirmation_sent_at: Time.zone.now,
        unconfirmed_email: 'test@example.com'
      )

      stub_analytics
      allow(@analytics).to receive(:track_event)

      analytics_hash = {
        success: true,
        errors: {},
        user_id: user.uuid,
        existing_user: true,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :create, confirmation_token: 'foo'
    end
  end
end
