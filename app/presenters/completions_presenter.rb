# frozen_string_literal: true

class CompletionsPresenter
  include ActionView::Helpers::TranslationHelper
  include ActionView::Helpers::TagHelper

  attr_reader :current_user, :current_sp, :decrypted_pii, :requested_attributes,
              :completion_context, :selected_email_id

  SORTED_IDV_ATTRIBUTE_MAPPING = [
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

  SORTED_AUTH_ONLY_ATTRIBUTE_MAPPING = [
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
    idv_requested:,
    completion_context:,
    selected_email_id:
  )
    @current_user = current_user
    @current_sp = current_sp
    @decrypted_pii = decrypted_pii
    @requested_attributes = requested_attributes
    @idv_requested = idv_requested
    @completion_context = completion_context
    @selected_email_id = selected_email_id
  end

  def idv_requested?
    @idv_requested
  end

  def sp_name
    @sp_name ||= current_sp.friendly_name || sp.agency&.name
  end

  def heading
    if idv_requested?
      if consent_has_expired?
        I18n.t('titles.sign_up.completion_consent_expired_idv')
      elsif reverified_after_consent?
        I18n.t(
          'titles.sign_up.completion_reverified_consent',
          sp: sp_name,
        )
      else
        I18n.t('titles.sign_up.completion_idv', sp: sp_name)
      end
    elsif first_time_signing_in?
      I18n.t('titles.sign_up.completion_first_sign_in', sp: sp_name)
    elsif consent_has_expired?
      I18n.t('titles.sign_up.completion_consent_expired_auth_only')
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
    elsif idv_requested? && reverified_after_consent?
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

  def token_exchange_sharing?
    current_sp.token_exchange_broker_allowed? &&
      requested_attributes.map(&:to_s).include?('token_exchange')
  end

  def token_exchange_sharing_disclosure
    t('help_text.requested_attributes.token_exchange_html', sp_html: content_tag(:strong, sp_name))
  end

  # The applications the user has already linked to their account that the
  # broker may reach, grouped by agency for the per-application chooser.
  # @return [Array<[Agency, Array<ServiceProvider>]>]
  def token_exchange_linked_targets_by_agency
    @token_exchange_linked_targets_by_agency ||=
      TokenExchangeReachableTargets.grouped_by_agency(token_exchange_linked_targets)
  end

  # @return [Array<ServiceProvider>]
  def token_exchange_linked_targets
    @token_exchange_linked_targets ||= TokenExchangeReachableTargets.linked_for(
      user: current_user, broker_issuer: current_sp.issuer,
    )
  end

  # With no linked agencies there is nothing to "allow all" for; only the
  # auto-enrollment option is offered.
  def token_exchange_has_linked_targets?
    token_exchange_linked_targets.any?
  end

  # The user's CURRENT token-exchange state for this broker, used to pre-populate
  # the control on a return visit so that simply continuing preserves (rather
  # than silently revokes) grants the user already made here or on the account
  # page. Nothing is pre-checked for a first-time grant.
  def token_exchange_current_targets
    @token_exchange_current_targets ||= TokenExchangeGrant.active
      .where(user: current_user, broker_issuer: current_sp.issuer)
      .pluck(:target_issuer)
  end

  def token_exchange_currently_all?
    token_exchange_has_linked_targets? &&
      (token_exchange_linked_targets.map(&:issuer) - token_exchange_current_targets).empty?
  end

  def token_exchange_currently_auto_enroll?
    TokenExchangeBrokerSetting.for(user: current_user, broker_issuer: current_sp.issuer)
      .auto_enroll_enabled?
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
    sorted_attribute_mapping = if idv_requested?
                                 SORTED_IDV_ATTRIBUTE_MAPPING
                               else
                                 SORTED_AUTH_ONLY_ATTRIBUTE_MAPPING
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
