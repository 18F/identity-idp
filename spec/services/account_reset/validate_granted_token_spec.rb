require 'rails_helper'

RSpec.describe AccountReset::ValidateGrantedToken do
  include AccountResetHelper

  let(:expired_token_message) do
    t('errors.account_reset.granted_token_expired', app_name: APP_NAME)
  end
  let(:expired_token_error) { { token: [expired_token_message] } }
  let(:user) { create(:user) }
  let(:request) { FakeRequest.new }
  let(:analytics) { FakeAnalytics.new }
  let(:fake_attempts_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }

  let(:service_provider) do
    create(
      :service_provider,
      active: true,
      redirect_uris: ['http://localhost:7654/auth/result'],
      ial: 2,
      irs_attempts_api_enabled: true,
    )
  end

  describe '#call' do
    context 'track irs event' do
      before do
        allow_any_instance_of(AccountReset::ValidateGrantedToken).to receive(
          :irs_attempts_api_tracker,
        ).and_return(fake_attempts_tracker)
      end

      it 'logs attempts api event with failure reason if the token is expired' do
        expect(fake_attempts_tracker).to receive(:account_reset_account_deleted).with(
          success: false,
          failure_reason: expired_token_error,
        )

        create_account_reset_request_for(user, service_provider.issuer)
        grant_request(user)

        travel_to(Time.zone.now + 2.days) do
          token = AccountResetRequest.first.granted_token
          AccountReset::ValidateGrantedToken.new(token, request, analytics).call
        end
      end
    end
  end
end
