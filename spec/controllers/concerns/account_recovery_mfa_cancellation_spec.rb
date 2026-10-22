require 'rails_helper'

# A user who successfully authenticates with an existing method has regained
# access, so an unredeemed recovery request is cancelled at the authentication
# boundary. Once the recovery link has been redeemed the request must survive
# normal authentication, since it stays in flight until replacement MFA is added.
RSpec.describe TwoFactorAuthenticatableMethods do
  let(:user) { create(:user, :fully_registered) }

  controller ApplicationController do
    include TwoFactorAuthenticatableMethods
  end

  before do
    allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(false)
    stub_sign_in_before_2fa(user)
  end

  def authenticate
    controller.send(
      :mark_user_session_authenticated,
      auth_method: TwoFactorAuthenticatable::AuthMethod::SMS,
      authentication_type: :valid_2fa,
    )
  end

  describe '#mark_user_session_authenticated' do
    it 'cancels a waiting request' do
      recovery_request = create(:account_recovery_request, :waiting, user: user)

      authenticate

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(recovery_request.cancel_reason).to eq('mfa_used')
    end

    it 'cancels a granted request and clears its tokens' do
      recovery_request = create(:account_recovery_request, :granted, user: user)

      authenticate

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(recovery_request.token_fingerprint).to be_nil
    end

    %i[link_verified password_verified replacement_mfa_pending].each do |state|
      it "does not cancel a #{state} request" do
        recovery_request = create(:account_recovery_request, state, user: user)

        expect { authenticate }.not_to change { ActionMailer::Base.deliveries.size }

        expect(recovery_request.reload.state).to eq(state.to_s)
      end
    end

    it 'does not cancel a request verified after it was loaded' do
      recovery_request = create(:account_recovery_request, :granted, user: user)
      allow(AccountRecoveryRequest).to receive(:active_for_user).with(user)
        .and_return(recovery_request)
      AccountRecoveryRequest.find(recovery_request.id)
        .transition_to!(AccountRecoveryRequest::LINK_VERIFIED)

      expect { authenticate }.not_to change { ActionMailer::Base.deliveries.size }

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
    end

    it 'notifies the user when a request is cancelled' do
      create(:account_recovery_request, :waiting, user: user)

      expect { authenticate }.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq(
        t('user_mailer.account_recovery_cancelled.mfa_used.subject', app_name: APP_NAME),
      )
    end

    it 'tells the user on the next page that the request was cancelled' do
      create(:account_recovery_request, :waiting, user: user)

      authenticate

      expect(controller.flash[:success]).to eq(
        t('account_recovery.cancelled_by_mfa_html', app_name: APP_NAME),
      )
    end

    it 'does not set a flash when there is nothing to cancel' do
      authenticate

      expect(controller.flash[:success]).to be_nil
    end

    it 'logs the cancellation' do
      stub_analytics
      create(:account_recovery_request, :waiting, user: user)

      authenticate

      expect(@analytics).to have_logged_event(
        :account_recovery_cancelled,
        reason: 'mfa_used',
        recovery_state: AccountRecoveryRequest::WAITING,
      )
    end

    it 'does nothing when the user has no recovery request' do
      expect { authenticate }.to_not change { ActionMailer::Base.deliveries.size }
    end

    it 'does not cancel another user’s request' do
      other_request = create(:account_recovery_request, :waiting)

      authenticate

      expect(other_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
    end
  end
end
