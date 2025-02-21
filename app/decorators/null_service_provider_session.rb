# frozen_string_literal: true

class NullServiceProviderSession
  def initialize(view_context: nil)
    @view_context = view_context
  end

  def new_session_heading
    I18n.t('headings.sign_in_without_sp')
  end

  def cancel_link_url
    view_context.root_url
  end

  def remember_device_default
    true
  end

  def sp_name; end

  def sp_issuer; end

  def sp_logo; end

  def sp_logo_url; end

  def sp_redirect_uris; end

  def requested_attributes; end

  def sp_alert(_section); end

  def successful_handoff?
    false
  end

  def requested_more_recent_verification?
    false
  end

  def request_url_params
    {}
  end

  def current_user
    view_context&.current_user
  end

  private

  attr_reader :view_context
end
