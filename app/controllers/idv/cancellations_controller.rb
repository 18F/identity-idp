module Idv
  class CancellationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.track_event(Analytics::IDV_CANCELLATION, properties)
      @go_back_path = go_back_path
    end

    def destroy
      analytics.track_event(Analytics::IDV_CANCELLATION_CONFIRMED)
      idv_session = user_session[:idv]
      idv_session&.clear
      reset_doc_auth
    end

    private

    def reset_doc_auth
      user_session.delete('idv/doc_auth')
      user_session['idv'] = { params: {}, step_attempts: { phone: 0 } }
    end

    def go_back_path
      referer_path || idv_path
    end

    def referer_path
      referer_string = request.env['HTTP_REFERER']
      return if referer_string.blank?
      referer_uri = URI.parse(referer_string)
      return if referer_uri.scheme == 'javascript'
      return unless referer_uri.host == AppConfig.env.domain_name
      extract_path_and_query_from_uri(referer_uri)
    end

    def extract_path_and_query_from_uri(uri)
      [uri.path, uri.query].compact.join('?')
    end
  end
end
