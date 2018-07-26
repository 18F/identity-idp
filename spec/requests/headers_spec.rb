require 'rails_helper'

RSpec.describe 'Headers' do
  it 'does not reflect header host values' do
    get root_path, headers: { 'X-Forwarded-Host' => 'evil.com' }

    expect(response.body).to_not include('evil.com')
  end

  it 'does not blow up with a malicious host value' do
    get root_path, headers: { 'Host' => "mTpvPME6'));select pg_sleep(9); --" }

    # it will redirect to the canonical host
    expect(response.code.to_i).to eq(301)
    expect(response).to redirect_to root_url
  end

  it 'does not blow up with bad formats in the headers' do
    get root_path, headers: { 'Accept' => 'acunetix/wvs' }

    expect(response.code.to_i).to eq(404)
  end

  it 'does not blow up with bad formats in the path' do
    get '/fr/users/password/new.zip'

    expect(response.code.to_i).to eq(404)
  end

  it 'does not raise an error when HTTP_HOST Header is encoded with ASCII-8BIT' do
    get root_path, headers: { 'Host' => '¿’¿”'.force_encoding(Encoding::ASCII_8BIT) }

    # it will redirect to the canonical host
    expect(response.status).to eq 301
    expect(response).to redirect_to root_url
  end
end
