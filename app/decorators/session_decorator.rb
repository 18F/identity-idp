class SessionDecorator
  include Rails.application.routes.url_helpers
  include ActionView::Helpers
  include ActionView::Helpers::TagHelper
  include LocaleHelper
  include ContentHelper

  def return_to_service_provider_partial
    'shared/null'
  end

  def return_to_sp_from_start_page_partial
    'shared/null'
  end

  def nav_partial
    'shared/nav_lite'
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

  def idv_hardfail4_partial
    'verify/no_sp_hardfail'
  end

  def sp_name; end

  def sp_logo; end

  def sp_return_url; end

  def requested_attributes; end

  def cancel_link_path
    root_path(locale: locale_url_param)
  end

  def warning_point_text(app_flow)
    warning_qualifier = I18n.t("#{app_flow}.cancel.warning_qualifier")
    warning_qualifier_tag = content_tag(:span, warning_qualifier, class: 'italic')

    warning_point_text_t(app_flow, warning_qualifier_tag)
  end

  private

  def warning_point_text_t(app_flow, warning_qualifier_tag)
    warning_point_text = I18n.t(
      "#{app_flow}.cancel.warning_point_no_sp",
      warning_qualifier: warning_qualifier_tag
    )
    safe_join(split_tag(warning_point_text, warning_qualifier_tag))
  end
end
