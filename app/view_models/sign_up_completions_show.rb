class SignUpCompletionsShow
  include ActionView::Helpers::TagHelper

  def initialize(ial2_requested:, decorated_session:, current_user:, handoff:, ialmax_requested:,
                 consent_has_expired:)
    @ial2_requested = ial2_requested
    @decorated_session = decorated_session
    @current_user = current_user
    @handoff = handoff
    @ialmax_requested = ialmax_requested
    @consent_has_expired = consent_has_expired
  end

  attr_reader :ial2_requested, :ialmax_requested, :decorated_session

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

  MAX_RECENT_IDENTITIES = 5

  # rubocop:disable Rails/OutputSafety
  def heading
    return handoff_heading if handoff?

    if requested_ial == 'ial2'
      return content_tag(:strong, I18n.t('titles.sign_up.verified', app_name: APP_NAME))
    end

    safe_join(
      [I18n.t(
        'titles.sign_up.completion_html',
        accent: content_tag(:strong, I18n.t('titles.sign_up.loa1')),
        app_name: APP_NAME,
      ).html_safe],
    )
  end
  # rubocop:enable Rails/OutputSafety

  def title
    if requested_ial == 'ial2'
      I18n.t('titles.sign_up.verified', app_name: APP_NAME)
    else
      I18n.t(
        'titles.sign_up.completion_html',
        accent: I18n.t('titles.sign_up.loa1'),
        app_name: APP_NAME,
      )
    end
  end

  def image_name
    "user-signup-#{requested_ial}.svg"
  end

  def requested_attributes_sorted
    sorted_attributes = sorted_attribute_mapping.map do |raw_attribute, display_attribute|
      display_attribute if (requested_attributes & raw_attribute).present?
    end.compact
    # If the SP requests all emails, there is no reason to show them the sign
    # in email address in the consent screen
    sorted_attributes.delete(:email) if sorted_attributes.include?(:all_emails)
    sorted_attributes
  end

  def sorted_attribute_mapping
    return SORTED_IAL2_ATTRIBUTE_MAPPING if user_verified?
    SORTED_IAL1_ATTRIBUTE_MAPPING
  end

  def identities
    if @current_user
      @identities ||= @current_user.identities.order(
        last_authenticated_at: :desc,
      ).limit(MAX_RECENT_IDENTITIES)
    else
      false
    end
  end

  def user_has_identities?
    if identities
      identities.length.positive?
    else
      false
    end
  end

  private

  def handoff_heading
    if consent_has_expired?
      content_tag(:strong, I18n.t('titles.sign_up.refresh_consent'))
    else
      content_tag(:strong, I18n.t('titles.sign_up.new_sp'))
    end
  end

  def handoff?
    @handoff
  end

  def consent_has_expired?
    @consent_has_expired
  end

  def requested_attributes
    decorated_session.requested_attributes.map(&:to_sym)
  end

  def user_verified?
    @current_user.decorate.identity_verified?
  end

  def requested_ial
    user_verified? ? 'ial2' : 'ial1'
  end
end
