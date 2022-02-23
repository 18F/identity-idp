require 'rails_helper'
COOKIE_SEPARATOR = "\n".freeze

RSpec.describe 'secure cookies' do
  it 'flags all cookies sent by the application as secure, httponly, and lax' do
    get root_url
    cookie_count = response.headers['Set-Cookie'].split(COOKIE_SEPARATOR).count

    expect(response.headers['Set-Cookie'].scan('; Secure').size).to eq(cookie_count)
    expect(response.headers['Set-Cookie'].scan('; HttpOnly').size).to eq(cookie_count)
    expect(response.headers['Set-Cookie'].scan('; SameSite=Lax').size).to eq(cookie_count)
  end
end
