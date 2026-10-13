require 'rails_helper'

RSpec.describe AccountRecovery::PendingController do
  let(:user) { create(:user, :fully_registered) }

  describe '#show' do
    it 'redirects to root if the user is not signed in' do
      get :show

      expect(response).to redirect_to root_url
    end

    context 'when signed in before 2FA' do
      before { stub_sign_in_before_2fa(user) }

      context 'without an active recovery request' do
        it 'renders a 404' do
          get :show

          expect(response).to render_template('pages/page_not_found')
        end
      end

      context 'when a terminal recovery request exists' do
        before { create(:account_recovery_request, :cancelled, user: user) }

        it 'renders a 404' do
          get :show

          expect(response).to render_template('pages/page_not_found')
        end
      end

      context 'with an active recovery request' do
        before { create(:account_recovery_request, :waiting, user: user) }

        it 'renders the pending page' do
          get :show

          expect(response).to render_template(:show)
        end

        it 'assigns the waiting period interval' do
          get :show

          expect(controller.view_assigns['waiting_period_interval']).to be_present
        end

        it 'does not cancel the request when rendering the pending page' do
          recovery_request = AccountRecoveryRequest.active_for_user(user)

          get :show

          expect(recovery_request.reload).to be_active
        end
      end
    end
  end
end
