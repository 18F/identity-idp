module LambdaCallback
  class AddressProofResultController < AuthTokenController
    def create
      dcs = DocumentCaptureSession.new
      dcs.result_id = result_id_parameter
      dcs.store_proofing_result(address_result_parameter.to_h)

      track_exception_in_result(address_result_parameter)
    end

    private

    def result_id_parameter
      params.require(:result_id)
    end

    def address_result_parameter
      params.require(:address_result).permit(:exception, :success, :timed_out,
                                             errors: {}, context: {})
    end

    def track_exception_in_result(result)
      exception = result[:exception]
      return if exception.nil?

      NewRelic::Agent.notice_error(exception)
      ExceptionNotifier.notify_exception(exception)
    end

    def config_auth_token
      AppConfig.env.address_proof_result_lambda_token
    end
  end
end
