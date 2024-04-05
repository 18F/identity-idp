require 'rails_helper'

RSpec.describe SignUp::PartnerAgencyExitController do
  describe '#show' do
    it 'tracks visit event' do
      stub_analytics
      expect(@analytics).to receive(:track_event).with('User Registration: enter email visited')

      get :new
    end
  end
end
