module Test
  class SingleLogoutService
    def initialize(params, settings)
      @params = params
      @settings = settings
    end

    def request?
      request
    end

    def response?
      params[:SAMLResponse]
    end

    def valid_request?
      return false unless request?

      logout_request.is_valid?
    end

    def log_event
      Rails.logger.info(event: 'IdP initiated logout', identity_uuid: logout_request.name_id)
    end

    def slo_response
      @slo_response ||= logout_response.create(
        settings,
        logout_request.id,
        nil,
        RelayState: params[:RelayState],
      )
    end

    private

    attr_reader :params, :settings

    def logout_response
      OneLogin::RubySaml::SloLogoutresponse.new
    end

    def logout_request
      @logout_request ||= OneLogin::RubySaml::SloLogoutrequest.new(request)
    end

    def request
      params[:SAMLRequest]
    end
  end
end
