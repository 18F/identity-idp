module TwoFactorAuthentication
  class PivCacPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.piv_cac_configurations&.any?
    end

    def enabled?
      configured?
    end

    def visible?
      enabled? || available?
    end

    def setup_required?(session)
      required?(session) && !enabled?
    end

    def required?(session)
      return if session.blank? || Figaro.env.allow_piv_cac_required != 'true'
      sp_session = session.fetch(:sp, {})
      sp_session[:requested_attributes]&.include?('x509_presented')
    end

    private

    attr_reader :user
  end
end
