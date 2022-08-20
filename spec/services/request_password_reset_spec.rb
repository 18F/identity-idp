require 'rails_helper'

RSpec.describe RequestPasswordReset do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:email) { user.email_addresses.first.email }
    let(:irs_attempts_api_tracker) do
      instance_double(IrsAttemptsApi::Tracker, forgot_password_email_sent: true)
    end

    before do
      allow(IrsAttemptsApi::Tracker).to receive(:new).and_return(irs_attempts_api_tracker)
    end

    context 'when the user is not found' do
      it 'sends the account registration email' do
        email = 'nonexistent@example.com'

        send_sign_up_email_confirmation = instance_double(SendSignUpEmailConfirmation)
        expect(send_sign_up_email_confirmation).to receive(:call).with(
          hash_including(
            instructions: I18n.t(
              'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
              app_name: APP_NAME,
            ),
          ),
        )
        expect(SendSignUpEmailConfirmation).to receive(:new).and_return(
          send_sign_up_email_confirmation,
        )

        RequestPasswordReset.new(
          email: email,
          irs_attempts_api_tracker: irs_attempts_api_tracker,
        ).perform
        user = User.find_with_email(email)
        expect(user).to be_present
        expect(RegistrationLog.first.user_id).to eq(user.id)
      end
    end

    context 'when the user is found and confirmed' do
      subject(:perform) do
        described_class.new(
          email: email,
          irs_attempts_api_tracker: irs_attempts_api_tracker,
        ).perform
      end

      before do
        allow(UserMailer).to receive(:reset_password_instructions).
          and_wrap_original do |impl, user, email, options|
            token = options.fetch(:token)
            expect(token).to be_present
            expect(Devise.token_generator.digest(User, :reset_password_token, token)).
              to eq(user.reset_password_token)

            impl.call(user, email, **options)
          end
      end

      it 'sends password reset instructions' do
        expect { subject }.
          to(change { user.reload.reset_password_token })
      end

      it 'sends a recovery activated push event' do
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryActivatedEvent.new(user: user))

        subject
      end

      it 'calls irs tracking method forgot_password_email_sent ' do
        subject

        expect(irs_attempts_api_tracker).to have_received(:forgot_password_email_sent)
      end
    end

    context 'when the user is found, not privileged, and not yet confirmed' do
      it 'sends password reset instructions' do
        allow(UserMailer).to receive(:reset_password_instructions).
          and_wrap_original do |impl, user, email, options|
            token = options.fetch(:token)
            expect(token).to be_present
            expect(Devise.token_generator.digest(User, :reset_password_token, token)).
              to eq(user.reset_password_token)

            impl.call(user, email, **options)
          end

        expect {
          RequestPasswordReset.new(
            email: email,
            irs_attempts_api_tracker: irs_attempts_api_tracker,
          ).perform
        }.
          to(change { user.reload.reset_password_token })
      end
    end

    context 'when the user is found and confirmed, but the email address is not' do
      let(:user) { create(:user, :with_multiple_emails) }

      let(:unconfirmed_email_address) do
        user.reload.email_addresses.last.tap do |email_address|
          email_address.update!(confirmed_at: nil)
        end
      end

      it 'sends the account registration email' do
        send_sign_up_email_confirmation = instance_double(SendSignUpEmailConfirmation)
        expect(send_sign_up_email_confirmation).to receive(:call).with(
          hash_including(
            instructions: I18n.t(
              'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
              app_name: APP_NAME,
            ),
          ),
        )
        expect(SendSignUpEmailConfirmation).to receive(:new).and_return(
          send_sign_up_email_confirmation,
        )

        RequestPasswordReset.new(
          email: unconfirmed_email_address.email,
        ).perform
      end

      it 'does not send a recovery activated push event' do
        expect(PushNotification::HttpPush).to_not receive(:deliver)

        RequestPasswordReset.new(
          email: unconfirmed_email_address.email,
        ).perform
      end
    end

    context 'when two users have the same email address' do
      let(:email) { 'aaa@test.com' }

      before do
        @user_unconfirmed = create(:user, email: email, confirmed_at: nil)
        @user_confirmed = create(:user, email: email, confirmed_at: Time.zone.now)
      end

      it 'always finds the user with the confirmed email address' do
        form = RequestPasswordReset.new(
          email: email,
          irs_attempts_api_tracker: irs_attempts_api_tracker,
        )
        form.perform

        expect(form.send(:user)).to eq(@user_confirmed)
        expect(irs_attempts_api_tracker).to have_received(:forgot_password_email_sent)
      end
    end

    context 'when the user requests password resets above the allowable threshold' do
      let(:analytics) { FakeAnalytics.new }
      it 'throttles the email sending and logs a throttle event' do
        max_attempts = IdentityConfig.store.reset_password_email_max_attempts

        max_attempts.times do
          expect {
            RequestPasswordReset.new(
              email: email, analytics: analytics,
              irs_attempts_api_tracker: irs_attempts_api_tracker
            ).perform
          }.
            to(change { user.reload.reset_password_token })
        end

        # extra time, throttled
        expect {
          RequestPasswordReset.new(
            email: email, analytics: analytics,
            irs_attempts_api_tracker: irs_attempts_api_tracker
          ).perform
        }.
          to_not(change { user.reload.reset_password_token })

        expect(analytics).to have_logged_event(
          'Throttler Rate Limit Triggered',
          throttle_type: :reset_password_email,
        )
        expect(irs_attempts_api_tracker).to have_received(:forgot_password_email_sent).with(
          email: email,
          success: false,
          failure_reason: { throttled: 'Rate limit triggered for the user.' }
        )
      end

      it 'only sends a push notification when the attempts have not been throttled' do
        max_attempts = IdentityConfig.store.reset_password_email_max_attempts

        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryActivatedEvent.new(user: user)).
          exactly(max_attempts).times

        max_attempts.times do
          expect {
            RequestPasswordReset.new(
              email: email, analytics: analytics,
              irs_attempts_api_tracker: irs_attempts_api_tracker
            ).perform
          }.
            to(change { user.reload.reset_password_token })
        end

        # extra time, throttled
        expect {
          RequestPasswordReset.new(
            email: email, analytics: analytics,
            irs_attempts_api_tracker: irs_attempts_api_tracker
          ).perform
        }.
          to_not(change { user.reload.reset_password_token })
      end
    end
  end
end
