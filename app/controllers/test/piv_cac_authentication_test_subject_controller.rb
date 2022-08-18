require 'digest'

# This is only used in development mode. Routes aren't constructed unless
# configured to be active.

module Test
  class PivCacAuthenticationTestSubjectController < ApplicationController
    include SecureHeadersConcern

    before_action :must_be_in_development
    before_action :apply_secure_headers_override

    def new
      @referrer = request.headers['Referer']
    end

    def create
      uri = referrer_uri
      uri.query = ''
      uri.fragment = ''
      uri.query = "token=TEST:#{CGI.escape(token_from_params)}"
      redirect_to uri.to_s
    end

    private

    def referrer_uri
      URI(params[:redirect_uri])
    end

    def must_be_in_development
      redirect_to root_url unless FeatureManagement.development_and_identity_pki_disabled?
    end

    def token_from_params
      error = params[:error]
      subject = params[:subject]

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
      data.merge(nonce: piv_session[:piv_cac_nonce])
    end

    def piv_session
      user_session || session
    end
  end
end
