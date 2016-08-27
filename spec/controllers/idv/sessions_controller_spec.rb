require 'rails_helper'

describe Idv::SessionsController do
  render_views

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666661234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66044'
    }
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  context 'user has created account' do
    before do
      sign_in(user)
    end

    context 'KBV on' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
      end

      it 'starts new proofing session' do
        get :index

        expect(response.status).to eq 200
        expect(response.body).to include t('idv.form.first_name')
      end

      it 'disallows duplicate SSN' do
        create(:profile, ssn: '1234')

        post :create, profile: user_attrs.merge(ssn: '1234')

        expect(response).to redirect_to(idv_sessions_dupe_url)
        expect(flash[:error]).to match t('idv.errors.duplicate_ssn')
      end

      it 'checks for required fields' do
        partial_attrs = user_attrs.dup
        partial_attrs.delete :first_name

        post :create, profile: partial_attrs

        expect(response).to render_template(:index)
        expect(response.body).to match 'can&#39;t be blank'
      end
    end
  end
end
