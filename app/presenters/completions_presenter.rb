class CompletionsPresenter
  attr_reader :current_user, :current_sp, :decrypted_pii, :requested_attributes, :completion_context

  SORTED_IAL2_ATTRIBUTE_MAPPING = [
    [%i[given_name family_name], :full_name],
    [[:address], :address],
    [[:phone], :phone],
    [[:email], :email],
    [[:all_emails], :all_emails],
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
    completion_context:
  )
    @current_user = current_user
    @current_sp = current_sp
    @decrypted_pii = decrypted_pii
    @requested_attributes = requested_attributes
    @ial2_requested = ial2_requested
    @completion_context = completion_context
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
    if ial2_requested?
      if consent_has_expired?
        I18n.t(
          'help_text.requested_attributes.ial2_consent_reminder_html',
          sp: sp_name,
        )
      else
        I18n.t(
          'help_text.requested_attributes.ial2_intro_html',
          sp: sp_name,
        )
      end
    elsif consent_has_expired?
      I18n.t(
        'help_text.requested_attributes.ial1_consent_reminder_html',
        sp: sp_name,
      )
    else
      I18n.t(
        'help_text.requested_attributes.ial1_intro_html',
        sp: sp_name,
      )
    end
  end

  def image_name
    if ial2_requested?
      'user-signup-ial2.svg'
    else
      'user-signup-ial1.svg'
    end
  end

  def pii
    displayable_attribute_keys.index_with do |attribute_name|
      displayable_pii[attribute_name]
    end
  end

  private

  def first_time_signing_in?
    current_user.identities.consented.where.not(last_consented_at: nil).empty?
  end

  def displayable_pii
    @displayable_pii ||= DisplayablePiiFormatter.new(
      current_user: current_user,
      pii: decrypted_pii,
    ).format
  end

  def consent_has_expired?
    completion_context == :consent_expired
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
