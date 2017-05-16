class SignUpCompletionsShow
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TagHelper

  def initialize(loa3_requested:)
    @loa3_requested = loa3_requested
  end

  attr_reader :loa3_requested

  def heading
    safe_join([I18n.t(
      'titles.sign_up.completion_html',
      accent: content_tag(:strong, I18n.t("titles.sign_up.#{requested_loa}")),
      app: APP_NAME
    ).html_safe])
  end

  def title
    I18n.t(
      'titles.sign_up.completion_html',
      accent: I18n.t("titles.sign_up.#{requested_loa}"),
      app: APP_NAME
    )
  end

  def image
    image_tag(
      helper.asset_url("user-signup-#{requested_loa}.svg"), width: 97, alt: '', class: 'mb2'
    )
  end

  private

  def requested_loa
    loa3_requested ? 'loa3' : 'loa1'
  end

  def helper
    ActionController::Base.helpers
  end
end
