# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Retired connected services route' do
  it 'permanently redirects GET /account/connected_services to the homepage' do
    get '/account/connected_services'

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to('/account')
  end

  it 'keeps the account_connected_services_path helper pointing at the retired path' do
    expect(account_connected_services_path).to eq('/account/connected_services')
  end
end
