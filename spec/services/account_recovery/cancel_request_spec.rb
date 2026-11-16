require 'rails_helper'

RSpec.describe AccountRecovery::CancelRequest do
  let(:user) { create(:user, :fully_registered) }
  let(:reason) { AccountRecoveryRequest::CANCEL_REASON_MFA_USED }

  subject(:service) { described_class.new(user: user, reason: reason) }

  it 'cancels an active request and emails the confirmed sign-in address once' do
    request = create(:account_recovery_request, :granted, user: user)
    sign_in_email = create(:email_address, user: user, last_sign_in_at: Time.zone.now)
    create(:email_address, user: user)

    expect { expect(service.call).to eq(true) }
      .to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
    expect(request.cancel_reason).to eq(reason)
    expect(request.token_fingerprint).to be_nil
    expect(ActionMailer::Base.deliveries.last.to).to eq([sign_in_email.email])

    expect { expect(service.call).to eq(false) }.not_to change { ActionMailer::Base.deliveries.size }
  end

  it 'reports the state the request was cancelled from' do
    create(:account_recovery_request, :waiting, user: user)

    expect(service.call).to eq(true)
    expect(service.recovery_state).to eq(AccountRecoveryRequest::WAITING)
  end

  it 'does not cancel another user’s request' do
    request = create(:account_recovery_request, :waiting)

    expect { expect(service.call).to eq(false) }
      .not_to change { ActionMailer::Base.deliveries.size }
    expect(request.reload).to be_active
  end

  %i[link_verified password_verified replacement_mfa_pending].each do |state|
    it "does not cancel a #{state} request" do
      request = create(:account_recovery_request, state, user: user)

      expect { expect(service.call).to eq(false) }
        .not_to change { ActionMailer::Base.deliveries.size }
      expect(request.reload.state).to eq(state.to_s)
      expect(service.recovery_state).to be_nil
    end
  end

  it 'does not cancel a request whose link was verified after it was loaded' do
    request = create(:account_recovery_request, :granted, user: user)
    allow(AccountRecoveryRequest).to receive(:active_for_user).with(user).and_return(request)
    AccountRecoveryRequest.find(request.id).transition_to!(AccountRecoveryRequest::LINK_VERIFIED)

    expect { expect(service.call).to eq(false) }
      .not_to change { ActionMailer::Base.deliveries.size }
    expect(request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
  end

  it 'does not report success when email delivery fails' do
    request = create(:account_recovery_request, :waiting, user: user)
    delivery = instance_double(ActionMailer::MessageDelivery)
    allow(UserMailer).to receive(:with).and_return(double(account_recovery_cancelled: delivery))
    allow(delivery).to receive(:deliver_now_or_later)
      .and_raise(Net::SMTPFatalError.new('Notification delivery failed'))

    expect { service.call }.to raise_error(Net::SMTPFatalError)
    expect(request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
    expect(request.cancelled_at).to be_present
  end

  it 'delivers the notification after cancellation is committed' do
    request = create(:account_recovery_request, :waiting, user: user)
    open_transactions = request.class.connection.open_transactions
    delivery = instance_double(ActionMailer::MessageDelivery)
    allow(UserMailer).to receive(:with).and_return(double(account_recovery_cancelled: delivery))
    expect(delivery).to receive(:deliver_now_or_later) do
      expect(request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(request.class.connection.open_transactions).to eq(open_transactions)
    end

    expect(service.call).to eq(true)
  end

  it 'cancels an existing request even when new recovery is disabled' do
    request = create(:account_recovery_request, :waiting, user: user)
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

    expect(service.call).to eq(true)
    expect(request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
  end
end
