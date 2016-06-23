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
      expect(subject).to have_filters(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe 'user has created account' do
    it 'starts new proofing session' do
      sign_in(user)
      get :index
      expect(response.status).to eq 200
      expect(response.body).to include t('idv.form.first_name')
    end

    it 'creates proofing session' do
      sign_in(user)

      post :create, user_attrs

      expect(flash).to be_empty
      expect(response).to redirect_to(idv_questions_path)
    end
  end
end
