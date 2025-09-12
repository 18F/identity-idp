require 'rails_helper'

RSpec.describe AccountReset::DeleteAccount do
  include AccountResetHelper

  let(:user) { create(:user) }
  let(:request) { FakeRequest.new }
  let(:analytics) { FakeAnalytics.new }

  let(:service_provider) do
    create(
      :service_provider,
      active: true,
      redirect_uris: ['http://localhost:7654/auth/result'],
      ial: 2,
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

    context 'when user has an active profile that is in a DuplicateProfileSet' do
      let(:user) { create(:user, :fully_registered, password: ControllerHelper::VALID_PASSWORD) }
      let(:profile1) do
        create(
          :profile,
          :active,
          :facial_match_proof,
          user: user,
        )
      end
      let(:profile2) do
        create(
          :profile,
          :active,
          :facial_match_proof,
        )
      end
      let!(:duplicate_profile_set) do
        create(
          :duplicate_profile_set, profile_ids: [profile1.id, profile2.id],
                                  service_provider: 'random-sp'
        )
      end

      it 'tracks the self-service analytics' do
        create_account_reset_request_for(user)
        grant_request(user)
        stub_analytics

        token = AccountResetRequest.where(user_id: user.id).first.granted_token
        AccountReset::DeleteAccount.new(token, request, analytics).call

        expect(analytics).to have_logged_event(
          :one_account_self_service,
          source: :account_reset_delete,
          service_provider: duplicate_profile_set.service_provider,
          associated_profiles_count: duplicate_profile_set.profile_ids.count - 1,
          dupe_profile_set_id: duplicate_profile_set.id,
        )
      end
    end
  end
end
