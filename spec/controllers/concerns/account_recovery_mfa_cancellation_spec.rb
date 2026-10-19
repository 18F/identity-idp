require 'rails_helper'

# A user who successfully authenticates with an existing method has regained
# access, so an unredeemed recovery request is cancelled at the authentication
# boundary. Once the recovery link has been redeemed the request must survive
# normal authentication, since it stays in flight until replacement MFA is added.
RSpec.describe TwoFactorAuthenticatableMethods do
  let(:user) { create(:user, :fully_registered) }
  let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::SMS }

  controller ApplicationController do
    include TwoFactorAuthenticatableMethods
  end

  before do
    allow(IdentityConfig.store).to receive(:deliver_mail_async).and_return(false)
    stub_sign_in_before_2fa(user)
    stub_analytics
  end

  def authenticate
    controller.send(:cancel_account_recovery_request_for_mfa_use, auth_method: auth_method)
  end

  describe '#cancel_account_recovery_request_for_mfa_use' do
    it 'cancels a waiting request with the MFA-used reason' do
      recovery_request = create(:account_recovery_request, :waiting, user: user)

      authenticate

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(recovery_request.cancel_reason).to eq(AccountRecoveryRequest::CANCEL_REASON_MFA_USED)
      expect(controller.flash[:success]).to eq(t('account_recovery.pending.cancel_success'))
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
        expect(@analytics).not_to have_logged_event(:account_recovery_cancelled)
        expect(controller.flash[:success]).to be_nil
      end
    end

    it 'notifies the user when a request is cancelled' do
      create(:account_recovery_request, :waiting, user: user)

      expect { authenticate }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it 'logs the cancellation with the state and the method that was used' do
      create(:account_recovery_request, :waiting, user: user)

      authenticate

      expect(@analytics).to have_logged_event(
        :account_recovery_cancelled,
        reason: AccountRecoveryRequest::CANCEL_REASON_MFA_USED,
        recovery_state: AccountRecoveryRequest::WAITING,
        mfa_method: auth_method,
      )
    end

    context 'with a different authentication method' do
      let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::WEBAUTHN }

      it 'logs that method' do
        create(:account_recovery_request, :waiting, user: user)

        authenticate

        expect(@analytics).to have_logged_event(
          :account_recovery_cancelled,
          hash_including(mfa_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN),
        )
      end
    end

    it 'does nothing outside the authentication context' do
      recovery_request = create(:account_recovery_request, :waiting, user: user)
      controller.user_session[:context] = UserSessionContext::REAUTHENTICATION_CONTEXT

      expect { authenticate }.not_to change { ActionMailer::Base.deliveries.size }

      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
    end

    it 'does nothing when the user has no recovery request' do
      expect { authenticate }.to_not change { ActionMailer::Base.deliveries.size }

      expect(@analytics).not_to have_logged_event(:account_recovery_cancelled)
    end

    it 'does not cancel another user’s request' do
      other_request = create(:account_recovery_request, :waiting)

      authenticate

      expect(other_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
    end
  end
end
