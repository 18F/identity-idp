require 'rails_helper'

describe 'Twilio request validation' do
  after do
    page.driver.header 'X-Twilio-Signature', nil
  end

  it 'validates requests to the /api/voice/otp endpoint' do
    cipher = Gibberish::AES.new(Figaro.env.attribute_encryption_key)
    encrypted_code = cipher.encrypt('1234')

    twilio_post_voice({ encrypted_code: encrypted_code }, false)

    expect(page).to have_content 'Twilio Request Validation Failed.'
  end

  it 'renders the voice message text when the signature is valid' do
    cipher = Gibberish::AES.new(Figaro.env.attribute_encryption_key)
    encrypted_code = cipher.encrypt('1234')

    twilio_post_voice(encrypted_code: encrypted_code)

    expect(page).to have_content 'Hello! Your login.gov one time passcode is, 1, 2, 3, 4'
  end
end

def twilio_post_voice(tw_params = {}, use_correct_signature = true)
  post_path = '/api/voice/otp'
  post_sig = use_correct_signature ? correct_signature(tw_params, post_path) : nil
  twilio_post(tw_params, post_sig, post_path)
end

def twilio_post(tw_params, post_sig, post_url)
  page.driver.header post_header_name, post_sig
  page.driver.post post_url, tw_params
end

def correct_signature(tw_params, post_path = '')
  Twilio::Security::RequestValidator.new(Figaro.env.twilio_auth_token).
    build_signature_for("#{myhost}#{post_path}", tw_params)
end

def myhost
  Capybara.current_host || Capybara.default_host
end

def post_header_name
  'X-Twilio-Signature'
end
