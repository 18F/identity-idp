class CancellationPresenter < FailurePresenter
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  delegate :request, to: :view_context

  attr_reader :view_context

  def initialize(view_context:)
    super(:warning)
    @view_context = view_context
  end

  def title
    t('headings.cancellations.prompt')
  end

  def header
    t('headings.cancellations.prompt')
  end

  def cancellation_warnings
    [
      t('users.delete.bullet_1', app: APP_NAME),
      t('users.delete.bullet_2_loa1'),
      t('users.delete.bullet_3', app: APP_NAME),
    ]
  end

  def go_back_path
    referer_path || two_factor_options_path
  end

  private

  def referer_path
    referer_string = request.env['HTTP_REFERER']
    return if referer_string.blank?
    referer_uri = URI.parse(referer_string)
    return if referer_uri.scheme == 'javascript'
    return unless referer_uri.host == Figaro.env.domain_name.split(':')[0]
    extract_path_and_query_from_uri(referer_uri)
  end

  def extract_path_and_query_from_uri(uri)
    [uri.path, uri.query].compact.join('?')
  end
end
