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

        it 'assigns only the email address used to sign in' do
          signed_in_email = create(:email_address, user: user, last_sign_in_at: Time.zone.now)
          create(:email_address, user: user)
          create(:email_address, user: user, confirmed_at: nil)
          create(:email_address)

          get :show

          expect(controller.view_assigns['email']).to eq(signed_in_email.email)
        end

        it 'does not cancel the request when rendering the pending page' do
          recovery_request = AccountRecoveryRequest.active_for_user(user)

          get :show

          expect(recovery_request.reload).to be_active
        end

        it 'does not send more notifications when the confirmation page is refreshed' do
          expect do
            get :show
            get :show
          end.not_to change { ActionMailer::Base.deliveries.size }
        end
      end
    end
  end
end
