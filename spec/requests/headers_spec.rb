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

  it 'does not raise an error when HTTP_HOST Header is encoded with ASCII-8BIT' do
    get root_path, headers: { 'Host' => '¿’¿”'.force_encoding(Encoding::ASCII_8BIT) }

    expect(response.status).to eq 200
  end

  context 'secure headers' do
    it 'sets the right values for X-headers' do
      get root_path

      aggregate_failures do
        expect(response.headers['X-Frame-Options']).to eq('DENY')
        expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
        expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
        expect(response.headers['X-Download-Options']).to eq('noopen')
        expect(response.headers['X-Permitted-Cross-Domain-Policies']).to eq('none')
      end
    end
  end
end
