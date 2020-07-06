class IdentityMonitor
  attr_reader :context

  def initialize(context)
    @context = context
  end

  def setup
    if local?
      context.create(:user, email: sms_sign_in_email, password: password)
    else
      inbox_clear
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
    ENV["#{lower_env}_IDP_URL"].to_s + '/users/password/new'
  end

  def lower_env
  end

  def local?
    defined?(Rails) && Rails.env.test?
  end

  def remote?
    !local?
  end

  # local tests use "example.com" as the domain in emails but they actually
  # render on localhost, so we need to patch them to be relative
  def to_local_url(url)
    URI(url).tap do |uri|
      uri.scheme = nil
      uri.host = nil
    end.to_s
  end

  # GmailHelper
  def check_for_password_reset_link
    password_reset_link_regex = /(?<link>https?:.+reset_password_token=[\w\-]+)/

    if local?
      body = ActionMailer::Base.deliveries.last.body.parts.first.to_s
      if (match = body.match(password_reset_link_regex))
        to_local_url(match[:link])
      end
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
