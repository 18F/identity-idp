require 'rails_helper'

RSpec.describe SignInSecurityCheckFailedController do
  describe '#show' do
    it 'logs an event' do
      stub_analytics
      get :show
      expect(@analytics).to have_logged_event(:sign_in_security_check_failed_visited)
    end
  end
end
