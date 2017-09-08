require 'rails_helper'

RSpec.describe 'Headers' do
  it 'does not reflect header host values' do
    get root_path, headers: { 'X-Forwarded-Host' => 'evil.com' }

    expect(response.body).to_not include('evil.com')
  end
end
