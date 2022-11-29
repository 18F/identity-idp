module Flow
  module Failure
    private

    def failure(message, extra = nil)
      flow_session[:error_message] = message
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end
  end
end
