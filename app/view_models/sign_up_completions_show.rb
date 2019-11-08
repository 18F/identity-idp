class SignUpCompletionsShow
  include ActionView::Helpers::TagHelper

  def initialize(ial2_requested:, decorated_session:, current_user:, handoff:)
    @ial2_requested = ial2_requested
    @decorated_session = decorated_session
    @current_user = current_user
    @handoff = handoff
  end

  attr_reader :ial2_requested, :decorated_session

  SORTED_IAL2_ATTRIBUTE_MAPPING = [
    [%i[given_name family_name], :full_name],
    [[:address], :address],
    [[:phone], :phone],
    [[:email], :email],
    [[:birthdate], :birthdate],
    [[:social_security_number], :social_security_number],
    [[:x509_subject], :x509_subject],
  ].freeze

  SORTED_IAL1_ATTRIBUTE_MAPPING = [
    [[:email], :email],
    [[:x509_subject], :x509_subject],
  ].freeze

  MAX_RECENT_IDENTITIES = 5

  # rubocop:disable Rails/OutputSafety
  def heading
    return content_tag(:strong, I18n.t('titles.sign_up.new_sp')) if handoff?
    if requested_ial == 'ial2'
      return content_tag(:strong, I18n.t('titles.sign_up.verified', app: APP_NAME))
    end

    safe_join([I18n.t(
      'titles.sign_up.completion_html',
      accent: content_tag(:strong, I18n.t('titles.sign_up.loa1')),
      app: APP_NAME,
    ).html_safe])
  end
  # rubocop:enable Rails/OutputSafety

  def title
    if requested_ial == 'ial2'
      I18n.t('titles.sign_up.verified')
    else
      I18n.t(
        'titles.sign_up.completion_html',
        accent: I18n.t('titles.sign_up.loa1'),
        app: APP_NAME,
      )
    end
  end

  def image_name
    "user-signup-#{requested_ial}.svg"
  end

  def requested_attributes_partial
    'sign_up/completions/requested_attributes'
  end

  def requested_attributes_sorted
    sorted_attribute_mapping.map do |raw_attribute, display_attribute|
      display_attribute if (requested_attributes & raw_attribute).present?
    end.compact
  end

  def sorted_attribute_mapping
    ial2_requested ? SORTED_IAL2_ATTRIBUTE_MAPPING : SORTED_IAL1_ATTRIBUTE_MAPPING
  end

  def identities_partial
    'shared/user_identities'
  end

  def service_provider_partial
    if @decorated_session.is_a?(ServiceProviderSessionDecorator)
      'sign_up/completions/show_sp'
    else
      'sign_up/completions/show_identities'
    end
  end

  def identities
    if @current_user
      @identities ||= @current_user.identities.order(
        last_authenticated_at: :desc,
      ).limit(MAX_RECENT_IDENTITIES).map(&:decorate)
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

  def handoff?
    @handoff
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
