require 'rails_helper'

RSpec.describe RequestPasswordReset do
  describe '#perform' do
    let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
    let(:user) { create(:user) }
    let(:request_id) { SecureRandom.uuid }
    let(:email_address) { user.email_addresses.first }
    let(:email) { email_address.email }

    context 'when the user is not found' do
      it 'sends the user missing email' do
        email = 'nonexistent@example.com'

        mailer = instance_double(AnonymousMailer)
        mail = instance_double(ActionMailer::MessageDelivery)
        expect(AnonymousMailer).to receive(:with).with(email:).and_return(mailer)
        expect(mailer).to receive(:password_reset_missing_user).with(request_id:).and_return(mail)
        expect(mail).to receive(:deliver_now)

        RequestPasswordReset.new(
          email: email,
          request_id: request_id,
        ).perform
      end
    end

    context 'when the user is found' do
      subject(:perform) do
        described_class.new(email:, attempts_api_tracker:).perform
      end

      before do
        allow(UserMailer).to receive(:reset_password_instructions)
          .and_wrap_original do |impl, user, email, options|
            token = options.fetch(:token)
            expect(token).to be_present
            expect(Devise.token_generator.digest(User, :reset_password_token, token))
              .to eq(user.reset_password_token)

            impl.call(user, email, **options)
          end
      end

      it 'sets password reset token' do
        expect { subject }
          .to(change { user.reload.reset_password_token })
      end

      it 'sends the correct email to the user' do
        subject

        expect_delivered_email_count(1)
        expect_delivered_email(
          to: [email],
          subject: t('user_mailer.reset_password_instructions.subject'),
        )
      end

      it 'sends a recovery activated push event' do
        expect(PushNotification::HttpPush).to receive(:deliver)
          .with(PushNotification::RecoveryActivatedEvent.new(user: user))

        subject
      end

      it 'records the attempts api event' do
        expect(attempts_api_tracker).to receive(:forgot_password_email_sent).with(email:)
        subject
      end
    end

    context 'when the user is found, but is suspended' do
      subject(:perform) do
        described_class.new(email:).perform
      end

      before do
        user.suspend!
        allow(UserMailer).to receive(:reset_password_instructions)
          .and_wrap_original do |impl, user, email, options|
          token = options.fetch(:token)
          expect(token).to be_present
          expect(Devise.token_generator.digest(User, :reset_password_token, token))
            .to eq(user.reset_password_token)

          impl.call(user, email, **options)
        end
        allow(UserMailer).to receive(:suspended_reset_password)
          .and_wrap_original do |impl, user, email, options|
            token = options.fetch(:token)
            expect(token).not_to be_present

            impl.call(user, email, **options)
          end
      end

      it 'does not set a password reset token' do
        expect { subject }
          .not_to(change { user.reload.reset_password_token })
      end

      it 'sends an email to the suspended user' do
        subject

        expect_delivered_email_count(1)
        expect_delivered_email(
          to: [email],
          subject: t('user_mailer.suspended_reset_password.subject'),
        )
      end

      it 'does not send a recovery activated push event' do
        expect(PushNotification::HttpPush).not_to receive(:deliver)
          .with(PushNotification::RecoveryActivatedEvent.new(user: user))

        subject
      end
    end

    context 'when the user is found, not privileged, and not yet confirmed' do
      it 'sends password reset instructions' do
        allow(UserMailer).to receive(:reset_password_instructions)
          .and_wrap_original do |impl, user, email, options|
            token = options.fetch(:token)
            expect(token).to be_present
            expect(Devise.token_generator.digest(User, :reset_password_token, token))
              .to eq(user.reset_password_token)

            impl.call(user, email, **options)
          end

        expect(attempts_api_tracker).to receive(:forgot_password_email_sent).with(email:)

        expect do
          RequestPasswordReset.new(email:, attempts_api_tracker:).perform
        end
          .to(change { user.reload.reset_password_token })
      end
    end

    context 'when the user is found and confirmed, but the email address is not' do
      let(:user) { create(:user, :with_multiple_emails) }
      let(:email_address) do
        user.reload.email_addresses.last.tap do |email_address|
          email_address.update!(confirmed_at: nil)
        end
      end

      it 'sends the user missing email' do
        mailer = instance_double(AnonymousMailer)
        mail = instance_double(ActionMailer::MessageDelivery)
        expect(AnonymousMailer).to receive(:with).with(email:).and_return(mailer)
        expect(mailer).to receive(:password_reset_missing_user).with(request_id:).and_return(mail)
        expect(mail).to receive(:deliver_now)

        RequestPasswordReset.new(
          email:,
          request_id:,
        ).perform
      end
    end

    context 'when two users have the same email address' do
      let(:email_param) { { email: 'aaa@test.com' } }

      before do
        @user_unconfirmed = create(:user, **email_param, confirmed_at: nil)
        @user_confirmed = create(:user, **email_param, confirmed_at: Time.zone.now)
      end

      it 'always finds the user with the confirmed email address' do
        form = RequestPasswordReset.new(**email_param, attempts_api_tracker:)
        expect(attempts_api_tracker).to receive(:forgot_password_email_sent).with(email_param)
        form.perform

        expect(form.send(:user)).to eq(@user_confirmed)
      end
    end

    context 'when the user requests password resets above the allowable threshold' do
      let(:analytics) { FakeAnalytics.new }
      it 'rate limits the email sending and logs a rate limit event' do
        max_attempts = IdentityConfig.store.reset_password_email_max_attempts

        expect(attempts_api_tracker).to receive(:forgot_password_email_sent)
          .with(email:)
          .exactly(max_attempts - 1)
          .times

        (max_attempts - 1).times do
          expect do
            RequestPasswordReset.new(
              email:,
              analytics:,
              attempts_api_tracker:,
            ).perform
          end
            .to(change { user.reload.reset_password_token })
        end

        # extra time, rate limited
        expect do
          RequestPasswordReset.new(
            email:,
            analytics:,
            attempts_api_tracker:,
          ).perform
        end
          .to_not(change { user.reload.reset_password_token })

        expect(analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :reset_password_email,
        )
      end

      it 'only sends a push notification when the attempts have not been rate limited' do
        max_attempts = IdentityConfig.store.reset_password_email_max_attempts

        expect(PushNotification::HttpPush).to receive(:deliver)
          .with(PushNotification::RecoveryActivatedEvent.new(user: user))
          .exactly(max_attempts - 1).times

        expect(attempts_api_tracker).to receive(:forgot_password_email_sent)
          .with(email:)
          .exactly(max_attempts - 1)
          .times

        (max_attempts - 1).times do
          expect do
            RequestPasswordReset.new(
              email:,
              analytics:,
              attempts_api_tracker:,
            ).perform
          end
            .to(change { user.reload.reset_password_token })
        end

        # extra time, rate limited
        expect do
          RequestPasswordReset.new(
            email:,
            analytics:,
            attempts_api_tracker:,
          ).perform
        end
          .to_not(change { user.reload.reset_password_token })
      end
    end
  end
end
