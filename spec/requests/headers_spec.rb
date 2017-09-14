require 'rails_helper'

RSpec.describe 'Headers' do
  it 'does not reflect header host values' do
    get root_path, headers: { 'X-Forwarded-Host' => 'evil.com' }

    expect(response.body).to_not include('evil.com')
  end

  it 'does not blow up with a malicious host value' do
    get root_path, headers: { 'Host' => "mTpvPME6'));select pg_sleep(9); --" }

    expect(response.code.to_i).to eq(200)
  end
end
