require 'digest'

# This is only used in development mode. Routes aren't constructed unless
# configured to be active.

module Test
  class PivCacAuthenticationTestSubjectController < ApplicationController
    before_action :must_be_in_development

    def new
      @referrer = request.headers['Referer']
    end

    # :reek:FeatureEnvy
    def create
      uri = referrer_uri
      uri.query = ''
      uri.fragment = ''
      uri.query = "token=TEST:#{CGI.escape(token_from_params)}"
      redirect_to uri.to_s
    end

    private

    def referrer_uri
      referrer = params[:referer]
      if referrer
        URI(referrer)
      else
        URI(setup_piv_cac_url)
      end
    end

    def must_be_in_development
      redirect_to root_url unless FeatureManagement.development_and_piv_cac_entry_enabled?
    end

    def token_from_params
      error, subject = params.slice(:error, :subject)

      if error.present?
        with_nonce(error: error).to_json
      elsif subject.present?
        uuid = Digest::SHA256.hexdigest(subject)
        with_nonce(dn: subject, uuid: uuid).to_json
      else
        with_nonce(error: 'certificate.none').to_json
      end
    end

    def with_nonce(data)
      data.merge(nonce: user_session[:piv_cac_nonce])
    end
  end
end
