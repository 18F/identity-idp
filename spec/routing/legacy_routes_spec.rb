require 'rails_helper'

RSpec.describe 'Connected services legacy redirects', type: :request do
  it 'redirects the old connected_accounts path to connected_services' do
    get '/account/connected_accounts'
    expect(response).to redirect_to('/account/connected_services')
  end

  it 'redirects the old selected_email path, preserving identity_id' do
    get '/account/connected_accounts/123/selected_email'
    expect(response).to redirect_to('/account/connected_services/123/selected_email')
  end
end
