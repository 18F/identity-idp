require 'rails_helper'

RSpec.describe Users::RulesOfUseController do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_signed_in,
        :confirm_need_to_accept_rules_of_use,
      )
    end
  end

  describe '#new' do
    subject(:action) { get :new }

    context 'with a user that has not accepted the rules of use' do
      before do
        sign_in_before_2fa_with_user_that_needs_to_accept_rules_of_use
      end

      it 'renders' do
        action
        expect(response).to render_template(:new)
      end

      it 'logs an analytics event for visiting' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with(Analytics::RULES_OF_USE_VISIT)

        action
      end
    end

    context 'with a user that has accepted the rules of use' do
      before do
        sign_in_before_2fa
      end

      it 'redirects to mfa' do
        action

        expect(response).to redirect_to user_two_factor_authentication_url
      end
    end

    context 'with no user signed in' do
      it 'redirects to root' do
        action

        expect(response).to redirect_to root_url
      end
    end
  end

  describe '#create' do
    subject(:action) do
      post :create, params: { user: { terms_accepted: 'true' } }
    end

    context 'when the user needs to accept the rules of use' do
      before do
        sign_in_before_2fa_with_user_that_needs_to_accept_rules_of_use
      end

      it 'updates the user accepted terms at timestamp' do
        action

        expect(controller.current_user.reload.accepted_terms_at).to be_present
      end

      it 'redirects to the two factor authentication page' do
        action

        expect(response).to redirect_to user_two_factor_authentication_url
      end

      it 'logs a successful analytics event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::RULES_OF_USE_SUBMITTED, hash_including(success: true))

        action
      end
    end
  end

  def sign_in_before_2fa_with_user_that_needs_to_accept_rules_of_use
    user = create(:user, :signed_up)
    UpdateUser.new(user: user, attributes: {accepted_terms_at: nil}).call
    sign_in_before_2fa(user)
  end
end
