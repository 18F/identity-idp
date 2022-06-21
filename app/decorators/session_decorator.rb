class SessionDecorator
  def initialize(view_context: nil)
    @view_context = view_context
  end

  def registration_heading
    'sign_up/registrations/registration_heading'
  end

  def new_session_heading
    I18n.t('headings.sign_in_without_sp')
  end

  def verification_method_choice
    I18n.t('idv.messages.select_verification_without_sp')
  end

  def cancel_link_url
    view_context.root_url
  end

  def mfa_expiration_interval
    IdentityConfig.store.remember_device_expiration_hours_aal_1.hours
  end

  def remember_device_default
    true
  end

  def sp_name; end

  def sp_logo; end

  def sp_logo_url; end

  def sp_redirect_uris; end

  def requested_attributes; end

  def sp_alert(_path); end

  def requested_more_recent_verification?
    false
  end

  def irs_attempts_api_session_id; end

  private

  attr_reader :view_context
end
