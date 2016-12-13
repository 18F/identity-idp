require 'rails_helper'

describe Verify::SessionsController do
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
        :confirm_two_factor_authenticated,
        :confirm_idv_attempts_allowed,
        :confirm_idv_needed
      )
    end
  end

  context 'user has created account' do
    render_views

    before do
      stub_sign_in(user)
    end

    context 'KBV on' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
      end

      it 'starts new proofing session' do
        get :new

        expect(response.status).to eq 200
        expect(response.body).to include t('idv.form.first_name')
      end

      it 'redirects to custom error on duplicate SSN' do
        create(:profile, pii: { ssn: '1234' })

        post :create, profile: user_attrs.merge(ssn: '1234')

        expect(response).to redirect_to(verify_session_dupe_path)
        expect(flash[:error]).to match t('idv.errors.duplicate_ssn')
      end

      it 'shows normal form with error on empty SSN' do
        post :create, profile: user_attrs.merge(ssn: '')

        expect(response).to_not redirect_to(verify_session_dupe_path)
        expect(response.body).to match t('errors.messages.blank')
      end

      it 'checks for required fields' do
        partial_attrs = user_attrs.dup
        partial_attrs.delete :first_name

        post :create, profile: partial_attrs

        expect(response).to render_template(:new)
        expect(response.body).to match t('errors.messages.blank')
      end
    end
  end
end
