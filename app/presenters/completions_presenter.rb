# frozen_string_literal: true

class CompletionsPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper
  include ActionView::Helpers::TagHelper

  attr_reader :current_user, :current_sp, :decrypted_pii, :requested_attributes,
              :completion_context, :selected_email_id, :url_options

  SORTED_IAL2_ATTRIBUTE_MAPPING = [
    [[:email], :email],
    [[:all_emails], :all_emails],
    [%i[given_name family_name], :full_name],
    [[:address], :address],
    [[:phone], :phone],
    [[:birthdate], :birthdate],
    [[:social_security_number], :social_security_number],
    [[:x509_subject], :x509_subject],
    [[:x509_issuer], :x509_issuer],
    [[:verified_at], :verified_at],
  ].freeze

  SORTED_IAL1_ATTRIBUTE_MAPPING = [
    [[:email], :email],
    [[:all_emails], :all_emails],
    [[:x509_subject], :x509_subject],
    [[:x509_issuer], :x509_issuer],
    [[:verified_at], :verified_at],
  ].freeze

  def initialize(
    current_user:,
    current_sp:,
    decrypted_pii:,
    requested_attributes:,
    ial2_requested:,
    completion_context:,
    selected_email_id:,
    url_options:
  )
    @current_user = current_user
    @current_sp = current_sp
    @decrypted_pii = decrypted_pii
    @requested_attributes = requested_attributes
    @ial2_requested = ial2_requested
    @completion_context = completion_context
    @selected_email_id = selected_email_id
    @url_options = url_options
  end

  def ial2_requested?
    @ial2_requested
  end

  def sp_name
    @sp_name ||= current_sp.friendly_name || sp.agency&.name
  end

  def heading
    if ial2_requested?
      if consent_has_expired?
        I18n.t('titles.sign_up.completion_consent_expired_ial2')
      elsif reverified_after_consent?
        I18n.t(
          'titles.sign_up.completion_reverified_consent',
          sp: sp_name,
        )
      else
        I18n.t('titles.sign_up.completion_ial2', sp: sp_name)
      end
    elsif first_time_signing_in?
      I18n.t('titles.sign_up.completion_first_sign_in', sp: sp_name)
    elsif consent_has_expired?
      I18n.t('titles.sign_up.completion_consent_expired_ial1')
    elsif completion_context == :new_attributes
      I18n.t('titles.sign_up.completion_new_attributes', sp: sp_name)
    else
      I18n.t('titles.sign_up.completion_new_sp')
    end
  end

  def intro
    if consent_has_expired?
      safe_join(
        [
          t(
            'help_text.requested_attributes.consent_reminder_html',
            sp_html: content_tag(:strong, sp_name),
          ),
          t('help_text.requested_attributes.intro_html', sp_html: content_tag(:strong, sp_name)),
        ],
        ' ',
      )
    elsif ial2_requested? && reverified_after_consent?
      t(
        'help_text.requested_attributes.ial2_reverified_consent_info_html',
        sp_html: content_tag(:strong, sp_name),
      )
    else
      t('help_text.requested_attributes.intro_html', sp_html: content_tag(:strong, sp_name))
    end
  end

  def pii
    displayable_attribute_keys.index_with do |attribute_name|
      displayable_pii[attribute_name]
    end
  end

  def email_change_link
    if current_user.confirmed_email_addresses.many?
      sign_up_select_email_path
    else
      add_email_path(in_select_email_flow: true)
    end
  end

  private

  def first_time_signing_in?
    current_user.identities.where.not(last_consented_at: nil).empty?
  end

  def displayable_pii
    @displayable_pii ||= DisplayablePiiFormatter.new(
      current_user: current_user,
      pii: decrypted_pii,
      selected_email_id: @selected_email_id,
    ).format
  end

  def consent_has_expired?
    completion_context == :consent_expired
  end

  def reverified_after_consent?
    completion_context == :reverified_after_consent
  end

  def displayable_attribute_keys
    sorted_attribute_mapping = if ial2_requested?
                                 SORTED_IAL2_ATTRIBUTE_MAPPING
                               else
                                 SORTED_IAL1_ATTRIBUTE_MAPPING
                               end

    sorted_attributes = sorted_attribute_mapping.map do |raw_attribute, display_attribute|
      display_attribute if (requested_attributes & raw_attribute).present?
    end
    # If the SP requests all emails, there is no reason to show them the sign
    # in email address in the consent screen
    sorted_attributes.delete(:email) if sorted_attributes.include?(:all_emails)
    sorted_attributes.compact
  end
end
