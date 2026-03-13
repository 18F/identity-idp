require 'rails_helper'

RSpec.describe Idv::InPerson::PostOfficeController do
  let(:user) { create(:user, :with_phone, with: { phone: '+1 (415) 555-0130' }) }

  before do
    allow(IdentityConfig.store).to receive(:in_person_out_of_react).and_return(true)
    Rails.application.reload_routes!
    stub_sign_in(user)
    # May need stub up to setup here
  end

  describe '#show' do
    before do
      get :show
    end

    it 'renders the show view' do
      expect(response).to render_template :show
    end
  end

  describe '#search' do
  end

  describe '#update' do
  end
end
