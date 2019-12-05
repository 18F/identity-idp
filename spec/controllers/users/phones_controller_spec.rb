require 'rails_helper'

describe Users::PhonesController do
  include Features::MailerHelper

  context 'user adds phone' do
    let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }
    let(:new_phone) { '202-555-4321' }
    before do
      stub_sign_in(user)

      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    it 'gives the user a form to enter a new phone number' do
      get :add
      expect(response).to render_template(:add)
    end
  end
end
