# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounts::ConnectedAccountsController do
  describe '#show' do
    let(:user) { create(:user, :fully_registered) }

    before do
      stub_sign_in(user) if user
    end

    it 'shows and logs a visit' do
      stub_analytics

      get :show

      expect(@analytics).to have_logged_event(:connected_accounts_page_visited)
    end
  end
end
