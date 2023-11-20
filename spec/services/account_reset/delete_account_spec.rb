require 'rails_helper'

RSpec.describe AccountReset::DeleteAccount do
  include AccountResetHelper

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
    it 'can be called even if DeletedUser exists' do
      create_account_reset_request_for(user)
      grant_request(user)
      token = AccountResetRequest.where(user_id: user.id).first.granted_token
      DeletedUser.create_from_user(user)
      AccountReset::DeleteAccount.new(token, request, analytics).call
    end

    context 'when user.confirmed_at is nil' do
      let(:user) { create(:user, confirmed_at: nil) }

      it 'does not blow up' do
        create_account_reset_request_for(user)
        grant_request(user)

        token = AccountResetRequest.where(user_id: user.id).first.granted_token
        expect do
          AccountReset::DeleteAccount.new(token, request, analytics).call
        end.to_not raise_error

        expect(User.find_by(id: user.id)).to be_nil
      end
    end

    context 'track irs event' do
      before do
        allow_any_instance_of(AccountReset::DeleteAccount).to receive(
          :irs_attempts_api_tracker,
        ).and_return(fake_attempts_tracker)
      end

      it 'logs attempts api event with success true if the token is good' do
        expect(fake_attempts_tracker).to receive(:account_reset_account_deleted).with(
          success: true,
        )

        create_account_reset_request_for(user, service_provider.issuer)
        grant_request(user)
        token = AccountResetRequest.where(user_id: user.id).first.granted_token
        AccountReset::DeleteAccount.new(token, request, analytics).call
      end

      it 'logs attempts api event with failure reason if the token is expired' do
        expect(fake_attempts_tracker).to receive(:account_reset_account_deleted).with(
          success: false,
        )

        create_account_reset_request_for(user, service_provider.issuer)
        grant_request(user)

        travel_to(Time.zone.now + 2.days) do
          token = AccountResetRequest.first.granted_token
          AccountReset::DeleteAccount.new(token, request, analytics).call
        end
      end
    end
  end
end
