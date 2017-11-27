class SignUpCompletionsShow
  include ActionView::Helpers::TagHelper

  def initialize(loa3_requested:, decorated_session:)
    @loa3_requested = loa3_requested
    @decorated_session = decorated_session
  end

  attr_reader :loa3_requested, :decorated_session

  SORTED_ATTRIBUTE_MAPPING = [
    [%i[given_name family_name], :full_name],
    [[:address], :address],
    [[:phone], :phone],
    [[:email], :email],
    [[:birthdate], :birthdate],
    [[:social_security_number], :social_security_number],
  ].freeze

  # rubocop:disable Rails/OutputSafety
  def heading
    safe_join([I18n.t(
      'titles.sign_up.completion_html',
      accent: content_tag(:strong, I18n.t("titles.sign_up.#{requested_loa}")),
      app: APP_NAME
    ).html_safe])
  end
  # rubocop:enable Rails/OutputSafety

  def title
    I18n.t(
      'titles.sign_up.completion_html',
      accent: I18n.t("titles.sign_up.#{requested_loa}"),
      app: APP_NAME
    )
  end

  def image_name
    "user-signup-#{requested_loa}.svg"
  end

  def requested_attributes_partial
    'sign_up/completions/requested_attributes'
  end

  def requested_attributes_sorted
    SORTED_ATTRIBUTE_MAPPING.map do |raw_attribute, display_attribute|
      display_attribute if (requested_attributes & raw_attribute).present?
    end.compact
  end

  private

  def requested_attributes
    decorated_session.requested_attributes.map(&:to_sym)
  end

  def requested_loa
    loa3_requested ? 'loa3' : 'loa1'
  end
end
