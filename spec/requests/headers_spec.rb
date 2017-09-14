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

  it 'does not blow up with bad formats in the headers' do
    get root_path, headers: { 'Accept' => 'acunetix/wvs' }

    expect(response.code.to_i).to eq(404)
  end

  it 'does not blow up with bad formats in the path' do
    get '/fr/users/password/new.zip'

    expect(response.code.to_i).to eq(404)
  end

  it 'ASCII encodes UTF8 headers' do
    get root_path, headers: { 'User-Agent' => 'Mózillá/5.0' }

    expect(request.env['HTTP_USER_AGENT'].ascii_only?).to eq(true)
  end
end
