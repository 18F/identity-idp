require 'rails_helper'

RSpec.describe Users::DeleteController do
  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_recently_authenticated_2fa,
      )
    end
  end

  describe '#show' do
    it 'shows and logs a visit' do
      stub_analytics
      stub_signed_in_user

      get :show

      expect(@analytics).to have_logged_event('Account Delete visited')
      expect(response).to render_template(:show)
    end
  end

  describe '#delete' do
    let(:password) { ControllerHelper::VALID_PASSWORD }
    subject(:delete) { post :delete, params: { user: { password: password } } }

    context 'with an incorrect password' do
      let(:password) { 'wrong' }

      it 'flashes a banner and renders the form' do
        stub_signed_in_user
        delete
        expect(response).to render_template(:show)
        expect(flash[:error]).to eq(t('idv.errors.incorrect_password'))
      end

      it 'does not delete the user' do
        stub_signed_in_user
        expect { delete }.to_not change(User, :count)
      end

      it 'logs a failed submit' do
        user = stub_signed_in_user
        stub_analytics(user:)
        stub_attempts_tracker
        expect(@attempts_api_tracker).to receive(:logged_in_account_purged).with(success: false)

        delete

        expect(@analytics).to have_logged_event('Account Delete submitted', success: false)
      end
    end

    it 'redirects to the root path' do
      stub_signed_in_user
      delete
      expect(response).to redirect_to root_url
    end

    it 'deletes user' do
      user = stub_signed_in_user
      expect(User.where(id: user.id).length).to eq(1)
      delete
      expect(User.where(id: user.id).length).to eq(0)
    end

    it 'emails user of account deletion' do
      allow(UserMailer).to receive(:account_delete_submitted).and_call_original
      stub_signed_in_user
      delete
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end

    it 'text user of account deletion' do
      allow(Telephony).to receive(:send_account_deleted_notice).and_call_original
      stub_signed_in_user
      delete
      expect(Telephony).to have_received(:send_account_deleted_notice)
    end

    it 'logs a succesful submit' do
      user = stub_signed_in_user
      stub_analytics(user:)
      stub_attempts_tracker
      expect(@attempts_api_tracker).to receive(:logged_in_account_purged).with(success: true)

      delete

      expect(@analytics).to have_logged_event('Account Delete submitted', success: true)
    end

    it 'does not delete identities to prevent uuid reuse' do
      user = stub_signed_in_user
      user.identities << ServiceProviderIdentity.create(
        service_provider: 'foo',
        last_authenticated_at: Time.zone.now,
      )
      expect(ServiceProviderIdentity.where(user_id: user.id).length).to eq(1)
      delete
      expect(ServiceProviderIdentity.where(user_id: user.id).length).to eq(1)
    end

    it 'deletes profile information for ial2' do
      user = stub_sign_in
      create(:profile, :active, :verified, user: user, pii: { ssn: '1234', dob: '1920-01-01' })
      expect(Profile.count).to eq(1)
      delete
      expect(Profile.count).to eq(0)
    end
  end

  def stub_signed_in_user
    user = create(
      :user,
      :fully_registered,
      :with_phone,
      email: 'old_email@example.com',
      password: ControllerHelper::VALID_PASSWORD,
    )
    stub_sign_in(user)
  end
end
