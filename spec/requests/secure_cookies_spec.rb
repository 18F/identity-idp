require 'rails_helper'

RSpec.describe 'secure cookies' do
  context 'with plain HTTP' do
    it 'flags all cookies sent by the application as HttpOnly and SameSite=Lax' do
      get root_url
      cookies = response.headers['Set-Cookie']
      cookie_count = cookies.count

      expect(cookies.count { |x| x.match?(SecureCookies::SECURE_REGEX) }).to eq(0)
      expect(cookies.count { |x| x.match?(SecureCookies::HTTP_ONLY_REGEX) }).to eq(cookie_count)
      expect(cookies.count { |x| x.match?(SecureCookies::SAME_SITE_REGEX) }).to eq(cookie_count)
    end
  end

  context 'with HTTPS' do
    it 'flags all cookies sent by the application as Secure, HttpOnly, and SameSite=Lax' do
      get root_url, headers: { 'HTTPS' => 'on' }
      cookie_count = response.headers['Set-Cookie'].count
      cookies = response.headers['Set-Cookie']

      expect(cookies.count { |x| x.match?(SecureCookies::SECURE_REGEX) }).to eq(cookie_count)
      expect(cookies.count { |x| x.match?(SecureCookies::HTTP_ONLY_REGEX) }).to eq(cookie_count)
      expect(cookies.count { |x| x.match?(SecureCookies::SAME_SITE_REGEX) }).to eq(cookie_count)
    end
  end

  it 'does not set an expiration on the session cookie' do
    get root_url
    cookies = response.headers['Set-Cookie']
    session_cookie = cookies.find { |x| x.include?(APPLICATION_SESSION_COOKIE_KEY) }
    expect(session_cookie).to_not include('expires=')
  end
end
