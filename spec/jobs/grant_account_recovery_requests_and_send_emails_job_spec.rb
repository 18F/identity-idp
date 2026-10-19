require 'rails_helper'

RSpec.describe GrantAccountRecoveryRequestsAndSendEmailsJob do
  let(:user) { create(:user, :fully_registered) }
  let(:user2) { create(:user, :fully_registered) }
  let(:now) { Time.zone.now }
  let(:wait_period_days) { 1 }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days)
      .and_return(wait_period_days)
    allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(false)
  end

  def create_waiting_request_for(recovery_user, requested_at:)
    create(
      :account_recovery_request,
      :waiting,
      user: recovery_user,
      requested_at: requested_at,
    )
  end

  describe '#perform' do
    it 'grants a request whose waiting period has elapsed' do
      recovery_request = create_waiting_request_for(user, requested_at: now - 2.days)

      notifications_sent = described_class.new.perform(now)

      expect(notifications_sent).to eq(1)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
      expect(recovery_request.granted_at).to be_present
    end

    it 'does not grant a request still inside the waiting period' do
      recovery_request = create_waiting_request_for(user, requested_at: now - 1.hour)

      notifications_sent = described_class.new.perform(now)

      expect(notifications_sent).to eq(0)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
    end

    it 'grants multiple eligible requests' do
      create_waiting_request_for(user, requested_at: now - 2.days)
      create_waiting_request_for(user2, requested_at: now - 3.days)

      expect(described_class.new.perform(now)).to eq(2)
    end

    it 'is idempotent across runs' do
      create_waiting_request_for(user, requested_at: now - 2.days)

      described_class.new.perform(now)

      expect(described_class.new.perform(now)).to eq(0)
    end

    it 'ignores requests that are not waiting' do
      create(:account_recovery_request, :granted, user: user, requested_at: now - 2.days)

      expect(described_class.new.perform(now)).to eq(0)
    end

    it 'ignores legacy account reset requests' do
      AccountResetRequest.create!(
        user: user,
        requested_at: now - 2.days,
        request_token: SecureRandom.uuid,
      )

      expect { described_class.new.perform(now) }
        .to_not change { AccountResetRequest.where.not(granted_at: nil).count }
    end

    it 'stores only a token fingerprint, never a raw token' do
      recovery_request = create_waiting_request_for(user, requested_at: now - 2.days)

      described_class.new.perform(now)
      recovery_request.reload

      expect(recovery_request.token_fingerprint).to be_present
      expect(recovery_request.attributes.keys).to_not include('token')
    end

    it 'emails the recovery link to the sign-in email address only' do
      signed_in_email = create(:email_address, user: user, last_sign_in_at: now)
      create(:email_address, user: user)
      create_waiting_request_for(user, requested_at: now - 2.days)

      expect { described_class.new.perform(now) }
        .to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([signed_in_email.email])
      expect(Capybara.string(mail.html_part.body.to_s)).to have_link(
        href: %r{/account_recovery/verify\?.*token=},
      )
      expect(Capybara.string(mail.html_part.body.to_s)).to have_link(
        I18n.t(
          'user_mailer.account_recovery_granted.cancel_link_text',
          app_name: APP_NAME,
        ),
      )
    end

    it 'delivers the email synchronously so raw tokens are never enqueued' do
      # deliver_later would serialize the raw tokens into the good_jobs table in
      # plaintext, defeating the point of storing only fingerprints.
      allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(true)
      create_waiting_request_for(user, requested_at: now - 2.days)

      delivery = instance_double(ActionMailer::MessageDelivery)
      allow(UserMailer).to receive(:with).and_return(
        double(account_recovery_granted: delivery),
      )
      expect(delivery).to receive(:deliver_now)
      expect(delivery).to_not receive(:deliver_later)
      expect(delivery).to_not receive(:deliver_now_or_later)

      described_class.new.perform(now)
    end

    it 'cancels and does not grant a request for a user who became ineligible' do
      recovery_request = create_waiting_request_for(user, requested_at: now - 2.days)
      create(:profile, :active, user: user)

      expect { described_class.new.perform(now) }
        .to_not change { ActionMailer::Base.deliveries.size }

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(recovery_request.token_fingerprint).to be_nil
    end

    it 'logs the number of notifications sent' do
      stub_analytics
      create_waiting_request_for(user, requested_at: now - 2.days)

      described_class.new.perform(now)

      expect(@analytics).to have_logged_event(:account_recovery_notifications, count: 1)
      expect(@analytics).to have_logged_event(:account_recovery_granted, success: true)
    end

    it 'does not grant a request for a user with no deliverable email address' do
      recovery_request = create_waiting_request_for(user, requested_at: now - 2.days)
      user.email_addresses.update_all(confirmed_at: nil)

      expect { described_class.new.perform(now) }
        .to_not change { ActionMailer::Base.deliveries.size }

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
      expect(recovery_request.token_fingerprint).to be_nil
    end

    context 'with a longer configured waiting period' do
      let(:wait_period_days) { 7 }

      it 'respects the configured period' do
        create_waiting_request_for(user, requested_at: now - 2.days)

        expect(described_class.new.perform(now)).to eq(0)
      end
    end
  end
end
