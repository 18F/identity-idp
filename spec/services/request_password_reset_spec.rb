require 'rails_helper'

RSpec.describe RequestPasswordReset do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:email) { user.email_addresses.first.email }

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

        RequestPasswordReset.new(email: email).perform
        user = User.find_with_email(email)
        expect(user).to be_present
        expect(RegistrationLog.first.user_id).to eq(user.id)
      end
    end

    context 'when the user is found and confirmed' do
      it 'sends password reset instructions' do
        allow(UserMailer).to receive(:reset_password_instructions).
          and_wrap_original do |impl, user, email, options|
            token = options.fetch(:token)
            expect(token).to be_present
            expect(Devise.token_generator.digest(User, :reset_password_token, token)).
              to eq(user.reset_password_token)

            impl.call(user, email, **options)
          end

        expect { RequestPasswordReset.new(email: email).perform }.
          to(change { user.reload.reset_password_token })
      end

      it 'sends a recovery activated push event' do
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryActivatedEvent.new(user: user))

        RequestPasswordReset.new(email: email).perform
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

        expect { RequestPasswordReset.new(email: email).perform }.
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

        RequestPasswordReset.new(email: unconfirmed_email_address.email).perform
      end

      it 'does not send a recovery activated push event' do
        expect(PushNotification::HttpPush).to_not receive(:deliver)

        RequestPasswordReset.new(email: unconfirmed_email_address.email).perform
      end
    end

    context 'when two users have the same email address' do
      let(:email) { 'aaa@test.com' }

      before do
        @user_unconfirmed = create(:user, email: email, confirmed_at: nil)
        @user_confirmed = create(:user, email: email, confirmed_at: Time.zone.now)
      end

      around do |example|
        # make the test more deterministic
        EmailAddress.default_scopes = [-> { order('id ASC') }]
        example.run
        EmailAddress.default_scopes = []
      end

      it 'always finds the user with the confirmed email address' do
        form = RequestPasswordReset.new(email: email)
        form.perform

        expect(form.send(:user)).to eq(@user_confirmed)
      end
    end

    context 'when the user requests password resets above the allowable threshold' do
      let(:analytics) { FakeAnalytics.new }
      it 'throttles the email sending and logs a throttle event' do
        max_attempts = IdentityConfig.store.reset_password_email_max_attempts

        max_attempts.times do
          expect { RequestPasswordReset.new(email: email, analytics: analytics).perform }.
            to(change { user.reload.reset_password_token })
        end

        # extra time, throttled
        expect { RequestPasswordReset.new(email: email, analytics: analytics).perform }.
          to_not(change { user.reload.reset_password_token })

        expect(analytics).to have_logged_event(
          Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
          throttle_type: :reset_password_email,
        )
      end

      it 'only sends a push notification when the attempts have not been throttled' do
        max_attempts = IdentityConfig.store.reset_password_email_max_attempts

        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryActivatedEvent.new(user: user)).
          exactly(max_attempts).times

        max_attempts.times do
          expect { RequestPasswordReset.new(email: email, analytics: analytics).perform }.
            to(change { user.reload.reset_password_token })
        end

        # extra time, throttled
        expect { RequestPasswordReset.new(email: email, analytics: analytics).perform }.
          to_not(change { user.reload.reset_password_token })
      end
    end
  end
end
