require 'rails_helper'

describe Users::AdditionalMfaRequiredController do
  let(:user) { build(:user, :with_phone) }

  before do
    allow(IdentityConfig.store).
      to receive(:kantara_2fa_phone_existing_user_restriction).
      and_return(true)
    stub_sign_in(user)
  end

  describe '#show' do
    it 'presents the additional mfa required prompt page.' do
      get :show

      expect(response.status).to eq 200
    end
  end

  describe '#skip' do
    let(:enforcement_date) { Time.zone.today + 6.days }
    before do
      allow(IdentityConfig.store).to receive(:kantara_restriction_enforcement_date).
      and_return(enforcement_date)
    end
    context 'before enforcement date' do
      it 'should redirect to user signin' do
        post :skip
        expect(response.status).to eq 302
      end
    end

    context 'after enforcement date, user has not skipped yet' do
      let(:enforcement_date) { Time.zone.today - 6.days }

      it 'should redirect user to sign in' do
        post :skip

        expect(response.status).to eq 302
      end

      it 'should add sin in attribute to users' do
        post :skip

        user.reload
        expect(user.non_restricted_mfa_required_prompt_skip_date).
        to be_truthy
      end
    end
  end
end
