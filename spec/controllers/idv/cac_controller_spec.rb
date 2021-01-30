require 'rails_helper'

describe Idv::CacController do
  let(:user) { create(:user) }
  let(:flow_session) do
    {
      'Idv::Steps::Cac::ChooseMethodStep' => true,
      'Idv::Steps::Cac::WelcomeStep' => true,
      'Idv::Steps::Cac::PresentCacStep' => true,
      'first_name' => 'Jane',
      'last_name' => 'Doe',
    }
  end
  let(:pii) do
    {
      first_name: 'jane',
      last_name: 'doe',
      address1: '1 road',
      city: 'Nowhere',
      state: 'Virginia',
      dob: '02/01/1934',
      zipcode: '66044',
      ssn: '111-11-1111',
    }
  end

  before do
    stub_sign_in(user)
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(controller).to have_actions(:sp_context_needed?)
    end
  end

  describe '#update' do
    it 'sets the uuid in session for the enter info step' do
      controller.user_session['idv/cac'] = flow_session
      put :update, params: { step: 'enter_info', doc_auth: pii }

      expect(controller.user_session['idv/cac'][:pii_from_doc]['uuid']).to eq(user.uuid)
    end
  end
end
