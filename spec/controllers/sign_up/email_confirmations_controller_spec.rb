require 'rails_helper'

describe SignUp::EmailConfirmationsController do
  describe '#create' do
    before do
      stub_analytics
    end

    it 'tracks nil email confirmation token' do
      analytics_hash = {
        success: false,
        errors: { confirmation_token: [t('errors.messages.blank')] },
        user_id: nil,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: nil }

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
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: '' }

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
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: "''" }

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
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: '""' }

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
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: 'foo' }
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
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: 'foo' }

      expect(flash[:error]).
        to eq t('errors.messages.confirmation_period_expired', period: '24 hours')
      expect(response).to redirect_to sign_up_email_resend_path
    end
  end

  describe 'Valid email confirmation tokens' do
    it 'tracks a valid email confirmation token event' do
      user = create(:user, :unconfirmed, confirmation_token: 'foo')

      stub_analytics

      analytics_hash = {
        success: true,
        errors: {},
        user_id: user.uuid,
        existing_user: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: 'foo' }
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

      analytics_hash = {
        success: true,
        errors: {},
        user_id: user.uuid,
        existing_user: true,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, analytics_hash)

      get :create, params: { confirmation_token: 'foo' }
    end
  end
end
