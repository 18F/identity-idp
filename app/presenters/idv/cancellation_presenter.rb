module Idv
  class CancellationPresenter < FailurePresenter
    include ActionView::Helpers::TranslationHelper

    delegate :idv_path,
             :request,
             to: :view_context

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
        t('idv.cancel.warnings.warning_1'),
        t('idv.cancel.warnings.warning_2'),
        t('idv.cancel.warnings.warning_3', app: APP_NAME),
        t('idv.cancel.warnings.warning_4'),
        t('idv.cancel.warnings.warning_5'),
      ]
    end

    def go_back_path
      referer_path || idv_path
    end

    private

    def referer_path
      referer_string = request.env['HTTP_REFERER']
      return if referer_string.blank?
      referer_uri = URI.parse(referer_string)
      return if referer_uri.scheme == 'javascript'
      return unless referer_uri.host == Figaro.env.domain_name
      extract_path_and_query_from_uri(referer_uri)
    end

    def extract_path_and_query_from_uri(uri)
      [uri.path, uri.query].compact.join('?')
    end
  end
end
