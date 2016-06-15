require 'rails_helper'

describe Idv::SessionsController do
  render_views

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }

  context 'user has created account' do
    it 'starts new proofing session' do
      get :index
      expect(response.status).to eq 200
      expect(response.body).to include t('idv.form.first_name')
    end

    it 'creates proofing session' do
      sign_in(user)

      post :create, {
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

      expect(flash).to be_empty
      expect(response).to redirect_to(idv_questions_path)
    end
  end
end
      
