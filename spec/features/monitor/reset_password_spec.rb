class IdentityMonitor
  attr_reader :context

  def initialize(context)
    @context = context
  end

  def setup
    if local?
      context.create(:user, email: sms_sign_in_email, password: password)
    end
  end

  def sms_sign_in_email
    ENV['SMS_SIGN_IN_EMAIL'] || 'test@example.com'
  end

  def password
    'salty pickles'
  end

  def inbox_clear
  end

  def idp_reset_password_url
    if local?
      context.new_user_password_url
    else
      ENV["#{lower_env}_IDP_URL"] + '/users/password/new'
    end
  end

  def local?
    defined?(Rails) && Rails.env.test?
  end

  def remote?
    !local?
  end

  # GmailHelper
  def check_for_password_reset_link
    if local?
      body = ActionMailer::Base.deliveries.last.body
      match = body.match(/(https?:.+reset_password_token=[\w\-]+)/)
      match[1] if match
    end
  end
end

RSpec.describe 'password reset' do
  let(:identity_monitor) { IdentityMonitor.new(self) }

  before { identity_monitor.setup }

  it 'resets password at LOA1' do
    visit identity_monitor.idp_reset_password_url
    fill_in 'password_reset_email_form_email', with: identity_monitor.sms_sign_in_email
    click_on 'Continue'

    expect(page).to have_content('Check your email')

    reset_link = identity_monitor.check_for_password_reset_link
    visit reset_link
    fill_in 'reset_password_form_password', with: identity_monitor.password
    click_on 'Change password'

    expect(page).to have_content('Your password has been changed')
  end
end
