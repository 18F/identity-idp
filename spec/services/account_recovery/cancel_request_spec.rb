require 'rails_helper'

RSpec.describe AccountRecovery::CancelRequest do
  let(:user) { create(:user, :fully_registered) }

  it 'cancels an active request and emails the confirmed sign-in address once' do
    request = create(:account_recovery_request, :granted, user: user)
    sign_in_email = create(:email_address, user: user, last_sign_in_at: Time.zone.now)
    create(:email_address, user: user)
    service = described_class.new(user: user)

    expect { expect(service.call).to eq(true) }
      .to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
    expect(request.token_fingerprint).to be_nil
    expect(ActionMailer::Base.deliveries.last.to).to eq([sign_in_email.email])

    expect { expect(service.call).to eq(false) }.not_to change { ActionMailer::Base.deliveries.size }
  end

  it 'does not cancel another user’s request' do
    request = create(:account_recovery_request, :waiting)

    expect { expect(described_class.new(user: user).call).to eq(false) }
      .not_to change { ActionMailer::Base.deliveries.size }
    expect(request.reload).to be_active
  end

  it 'does not report success when email delivery fails' do
    request = create(:account_recovery_request, :waiting, user: user)
    delivery = instance_double(ActionMailer::MessageDelivery)
    allow(UserMailer).to receive(:with).and_return(double(account_recovery_cancelled: delivery))
    allow(delivery).to receive(:deliver_now_or_later)
      .and_raise(Net::SMTPFatalError.new('Notification delivery failed'))

    expect { described_class.new(user: user).call }.to raise_error(Net::SMTPFatalError)
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

    expect(described_class.new(user: user).call).to eq(true)
  end

  it 'cancels an existing request even when new recovery is disabled' do
    request = create(:account_recovery_request, :waiting, user: user)
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

    expect(described_class.new(user: user).call).to eq(true)
    expect(request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
  end
end
