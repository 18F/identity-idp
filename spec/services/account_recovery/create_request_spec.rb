require 'rails_helper'

RSpec.describe AccountRecovery::CreateRequest do
  subject(:service) do
    described_class.new(user: user)
  end

  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
  end

  describe '#call' do
    context 'when notifying the user' do
      around do |example|
        original_adapter = ActiveJob::Base.queue_adapter
        example.run
      ensure
        ActiveJob::Base.queue_adapter = original_adapter
      end

      before do
        ActiveJob::Base.queue_adapter = :test
        allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(false)
      end

      it 'sends a request notification only to the email address used to sign in' do
        signed_in_email = create(:email_address, user: user, last_sign_in_at: Time.zone.now)
        create(:email_address, user: user)
        create(:email_address, user: user, confirmed_at: nil, last_sign_in_at: 1.minute.from_now)
        delivery_count = ActionMailer::Base.deliveries.size

        result = service.call

        expect(result).to be_success
        notifications = ActionMailer::Base.deliveries.drop(delivery_count)
        expect(notifications.map(&:to)).to eq([[signed_in_email.email]])
        expect(notifications.map(&:subject).uniq).to eq(
          [I18n.t('user_mailer.account_recovery_request.subject', app_name: APP_NAME)],
        )
      end

      it 'does not send another notification when a request already exists' do
        service.call

        expect { service.call }.not_to change { ActionMailer::Base.deliveries.size }
      end

      it 'queues a notification to the sign-in address when asynchronous delivery is enabled' do
        signed_in_email = create(:email_address, user: user, last_sign_in_at: Time.zone.now)
        allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(true)

        expect { service.call }.to have_enqueued_mail(UserMailer, :account_recovery_request).with(
          params: { user: user, email_address: signed_in_email },
          args: [],
        )
      end

      it 'does not send a notification for an ineligible user' do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

        expect { service.call }.not_to change { ActionMailer::Base.deliveries.size }
      end

      it 'does not report success when notification delivery fails' do
        delivery = instance_double(ActionMailer::MessageDelivery)
        allow(UserMailer).to receive(:with).and_return(
          double(account_recovery_request: delivery),
        )
        allow(delivery).to receive(:deliver_now_or_later)
          .and_raise(Net::SMTPFatalError.new('Notification delivery failed'))

        expect { service.call }.to raise_error(Net::SMTPFatalError)
        expect(AccountRecoveryRequest.active_for_user(user)).to be_present
      end
    end

    it 'creates a waiting request for an eligible user' do
      result = service.call

      expect(result.success?).to eq(true)

      request = AccountRecoveryRequest.active_for_user(user)
      expect(request).to be_present
      expect(request.state).to eq(AccountRecoveryRequest::WAITING)
      expect(request.requested_at).to be_present
    end

    it 'exposes the created request' do
      service.call

      expect(service.account_recovery_request).to eq(AccountRecoveryRequest.active_for_user(user))
    end

    it 'returns bounded, non-sensitive analytics attributes' do
      result = service.call

      expect(result.to_h).to include(
        success: true,
        recovery_state: AccountRecoveryRequest::WAITING,
      )
    end

    it 'does not issue a recovery token in phase 1' do
      service.call

      request = AccountRecoveryRequest.active_for_user(user)
      expect(request.token_fingerprint).to be_nil
      expect(request.token_expires_at).to be_nil
      expect(request.granted_at).to be_nil
    end

    it 'does not mutate any MFA configuration' do
      phone_count = user.phone_configurations.count

      service.call

      expect(user.reload.phone_configurations.count).to eq(phone_count)
    end

    context 'when the user is ineligible' do
      let(:user) { create(:user, :proofed) }

      it 'fails without creating a request' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq(['ineligible'])
        expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
      end
    end

    context 'when the feature is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'fails without creating a request' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
      end
    end

    context 'when the user is not fully registered' do
      let(:user) { create(:user, :with_phone) }

      it 'rejects the request without persisting recovery state' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq(['ineligible'])
        expect(AccountRecoveryRequest.where(user: user)).to be_empty
      end
    end

    context 'when eligibility evaluation raises an unexpected error' do
      before do
        allow(user).to receive(:active_profile?).and_raise(ActiveRecord::StatementInvalid)
      end

      it 'propagates the error without creating a request' do
        expect { service.call }.to raise_error(ActiveRecord::StatementInvalid)
        expect(AccountRecoveryRequest.where(user: user)).to be_empty
      end
    end

    context 'when the user already has an active recovery request' do
      let!(:existing_request) { create(:account_recovery_request, :waiting, user: user) }

      it 'is rejected by eligibility rather than superseding silently' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq(['ineligible'])
        expect(existing_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
      end
    end

    context 'when the user has a pending legacy account reset request' do
      before do
        AccountResetRequest.create!(
          user: user,
          request_token: SecureRandom.uuid,
          requested_at: Time.zone.now,
        )
      end

      it 'is rejected by eligibility' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq(['ineligible'])
      end
    end

    context 'when a prior recovery request is terminal' do
      before do
        create(:account_recovery_request, :cancelled, user: user)
      end

      it 'creates a new request and leaves the terminal one alone' do
        result = service.call

        expect(result.success?).to eq(true)
        expect(AccountRecoveryRequest.where(user: user).count).to eq(2)
        expect(AccountRecoveryRequest.active.where(user: user).count).to eq(1)
      end
    end

    context 'when the record cannot reach the waiting state' do
      before do
        allow_any_instance_of(AccountRecoveryRequest).to receive(:wait!).and_return(false)
      end

      it 'fails closed and leaves no stranded row behind' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq(['request_not_persisted'])
        expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
      end
    end
  end
end
