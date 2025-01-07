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

  describe '#confirm' do
    before do
    end
    context 'non-fraud user' do
      it 'should have @account_reset_deletion_period_interval to match regular wait period' do
        create_account_reset_request_for(user)

        get :confirm
        current_time = Time.zone.now
        time_in_hours = distance_of_time_in_words(
          current_time,
          current_time + IdentityConfig.store.account_reset_wait_period_days.days,
          true,
          accumulate_on: :hours,
        )
        expect(controller.view_assigns['account_reset_deletion_period_interval'])
          .to eq(time_in_hours)
      end
    end

    context 'fraud user' do
      let(:user) { create(:user, :fraud_review_pending) }
      context 'fraud wait period not set' do
        before do
          allow(IdentityConfig.store).to receive(:account_reset_fraud_user_wait_period_days)
            .and_return(nil)
        end

        it 'should have @account_reset_deletion_period to match regular wait period' do
          create_account_reset_request_for(user)

          get :confirm
          current_time = Time.zone.now
          time_in_hours = distance_of_time_in_words(
            current_time,
            current_time + IdentityConfig.store.account_reset_wait_period_days.days,
            true,
            accumulate_on: :hours,
          )
          expect(controller.view_assigns['account_reset_deletion_period_interval'])
            .to eq(time_in_hours)
        end
      end

      it 'should have @account_reset_deletion_period_interval to match fraud wait period' do
        create_account_reset_request_for(user)

        get :confirm
        current_time = Time.zone.now
        time_in_hours = distance_of_time_in_words(
          current_time,
          current_time + IdentityConfig.store.account_reset_fraud_user_wait_period_days.days,
          true,
          accumulate_on: :days,
        )
        expect(controller.view_assigns['account_reset_deletion_period_interval'])
          .to eq(time_in_hours)
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
        subject: t('user_mailer.account_reset_cancel.subject'),
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
