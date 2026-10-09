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
    selected_email_id:,
    requested_delegation_scopes: []
  )
    @current_user = current_user
    @current_sp = current_sp
    @decrypted_pii = decrypted_pii
    @requested_attributes = requested_attributes
    @idv_requested = idv_requested
    @completion_context = completion_context
    @selected_email_id = selected_email_id
    @requested_delegation_scopes = Array(requested_delegation_scopes).map(&:to_s)
  end

  def idv_requested?
    @idv_requested
  end

  def sp_name
    @sp_name ||= current_sp.friendly_name || sp.agency&.name
  end

  def heading
    # With delegation requested the screen leads with who is asking, so the heading names the
    # service provider and what it is being allowed.
    return t('sign_up.delegation.heading', sp: sp_name) if delegation_requested?

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

  # --- Delegated access consent ---------------------------------------------------------------

  # Whether this screen collects delegated-access consent: the service provider is approved for
  # delegation and named applications in this sign-in request.
  def delegation_requested?
    current_sp.delegation_service_provider? && requested_delegation_applications.any?
  end

  # One row per requested application. `status` is :new (no live approval), :approved (a live
  # approval that is remembered and current) or :updated (a live approval made stale by a material
  # content change). `approved_from_account_at` is set when the approval was given in advance on
  # the account page.
  DelegationRow = Struct.new(:application, :status, :approved_from_account_at, keyword_init: true)

  # Requested applications grouped under their agency, in request order. Every string shown comes
  # from the registry, never from the authorization request; the view renders it escaped.
  # @return [Array<[Agency, Array<DelegationRow>]>]
  def delegation_groups
    rows = requested_delegation_applications.map do |application|
      grant = live_grants_by_application_id[application.id]
      status =
        if grant.nil? || !grant.valid_now?
          grant&.current_content? == false ? :updated : :new
        else
          :approved
        end
      DelegationRow.new(
        application:,
        status:,
        approved_from_account_at: (grant.consented_at if grant&.source == 'account_page'),
      )
    end
    rows.group_by { |row| row.application.agency }.to_a
  end

  def delegation_logo_url
    current_sp.logo.present? ? current_sp.logo_url : nil
  end

  def delegation_operator_name
    current_sp.delegation_operator_legal_name.presence || sp_name
  end

  def delegation_service_description
    current_sp.delegation_service_description_for
  end

  def delegation_data_handling_statement
    current_sp.delegation_data_handling_statement_for
  end

  def delegation_uses_ai?
    current_sp.delegation_uses_ai?
  end

  def delegation_ai_description
    current_sp.delegation_ai_description_for
  end

  def delegation_learn_more_url
    current_sp.delegation_privacy_policy_url.presence
  end

  # The applications named in the request, as registry records, in request order. The screen
  # shows each application's agency and resource servers, so both are loaded up front rather than
  # once per row.
  def requested_delegation_applications
    @requested_delegation_applications ||= begin
      applications = DelegationApplications.requested(
        current_sp.issuer, @requested_delegation_scopes
      )
      ActiveRecord::Associations::Preloader.new(
        records: applications, associations: [:agency, :token_exchange_resource_servers],
      ).call
      applications
    end
  end

  def document_images_sharing?
    current_sp.document_images_sharing_allowed? &&
      requested_attributes.map(&:to_s).include?('document_images')
  end

  def document_images_sharing_disclosure
    t('help_text.requested_attributes.document_images_html', sp_html: content_tag(:strong, sp_name))
  end

  private

  # Live approvals for the requested applications, keyed by application id, each bound to the
  # application record already loaded (with its agency) for the screen.
  def live_grants_by_application_id
    @live_grants_by_application_id ||= TokenExchangeGrant.live_by_application(
      user: current_user, service_provider_issuer: current_sp.issuer,
      applications: requested_delegation_applications
    )
  end

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
