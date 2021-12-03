module Redirect
  class ReturnToSpController < Redirect::RedirectController
    before_action :validate_sp_exists

    def cancel
      redirect_url = sp_return_url_resolver.return_to_sp_url
      redirect_to_and_log redirect_url, event: Analytics::RETURN_TO_SP_CANCEL
    end

    def failure_to_proof
      redirect_url = sp_return_url_resolver.failure_to_proof_url
      redirect_to_and_log redirect_url, event: Analytics::RETURN_TO_SP_FAILURE_TO_PROOF
    end

    private

    def sp_return_url_resolver
      @sp_return_url_resolver ||= SpReturnUrlResolver.new(
        service_provider: current_sp,
        oidc_state: sp_request_params[:state],
        oidc_redirect_uri: sp_request_params[:redirect_uri],
      )
    end

    def sp_request_params
      @request_params ||= begin
        if sp_request_url.present?
          UriService.params(sp_request_url)
        else
          {}
        end
      end
    end

    def sp_request_url
      sp_session[:request_url] || service_provider_request&.url
    end

    def validate_sp_exists
      redirect_to account_url if current_sp.nil?
    end
  end
end
