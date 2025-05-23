require 'rails_helper'

RSpec.describe AccountReset::PendingController do
  include ActionView::Helpers::DateHelper
  include AccountResetHelper
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe '#show' do
    context 'when the account reset request does not exist' do
      it 'renders a 404' do
        get :show

        expect(response).to render_template('pages/page_not_found')
      end
    end
  end

  describe '#cancel' do
    it 'cancels the account reset request' do
      account_reset_request = AccountResetRequest.create(user: user, requested_at: 1.hour.ago)

      post :cancel

      expect(account_reset_request.reload.cancelled_at).to_not be_nil
      expect_delivered_email(
        to: [user.email_addresses.first.email],
        subject: t('user_mailer.account_reset_cancel.subject', app_name: APP_NAME),
      )
    end

    context 'when the account reset request does not exist' do
      it 'renders a 404' do
        post :cancel

        expect(response).to render_template('pages/page_not_found')
      end
    end
  end
end
