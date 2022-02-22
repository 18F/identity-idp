require 'rails_helper'

RSpec.describe 'secure cookies' do
  it 'flags all cookies sent by the application as secure, httponly, and lax' do
    get root_url

    expect(response.headers['Set-Cookie']).to include('; Secure')
    expect(response.headers['Set-Cookie']).to include('; HttpOnly')
    expect(response.headers['Set-Cookie']).to include('; SameSite=Lax')
  end
end
