require 'rails_helper'

RSpec.describe 'secure cookies' do
  context 'with plain HTTP' do
    it 'flags all cookies sent by the application as HttpOnly and SameSite=Lax' do
      get root_url
      cookie_count = response.headers['Set-Cookie'].split("\n").count

      expect(response.headers['Set-Cookie']).to_not include('; Secure')
      expect(response.headers['Set-Cookie'].scan('; HttpOnly').size).to eq(cookie_count)
      expect(response.headers['Set-Cookie'].scan('; SameSite=Lax').size).to eq(cookie_count)
    end
  end

  context 'with HTTPS' do
    it 'flags all cookies sent by the application as Secure, HttpOnly, and SameSite=Lax' do
      get root_url, headers: { 'HTTPS' => 'on' }
      cookie_count = response.headers['Set-Cookie'].split("\n").count

      expect(response.headers['Set-Cookie'].scan('; Secure').size).to eq(cookie_count)
      expect(response.headers['Set-Cookie'].scan('; HttpOnly').size).to eq(cookie_count)
      expect(response.headers['Set-Cookie'].scan('; SameSite=Lax').size).to eq(cookie_count)
    end
  end
end
