# frozen_string_literal: true

class NullServiceProviderSession
  def initialize(view_context: nil)
    @view_context = view_context
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

  def sp_issuer; end

  def sp_logo; end

  def sp_logo_url; end

  def sp_redirect_uris; end

  def requested_attributes; end

  def sp_alert(_section); end

  def requested_more_recent_verification?
    false
  end

  def request_url_params
    {}
  end

  def biometric_comparison_required?
    false
  end

  def current_user
    view_context&.current_user
  end

  def sp_aal
    1
  end

  def sp_ial
    1
  end

  def resolved_authn_context_result
    AuthnContextResolver.new(
      service_provider: 'null sp',
      vtr: ['C1'],
      acr_values: Vot::LegacyComponentValues::LOA1,
    ).resolve
  end

  private

  attr_reader :view_context
end
