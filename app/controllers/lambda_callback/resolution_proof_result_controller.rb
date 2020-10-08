module LambdaCallback
  class ResolutionProofResultController < AuthTokenController
    def create
      dcs = DocumentCaptureSession.new
      dcs.result_id = result_id_parameter
      dcs.store_proofing_result(resolution_result_parameter)

      track_exception_in_result(resolution_result_parameter)
    end

    private

    def result_id_parameter
      params.require(:result_id)
    end

    def resolution_result_parameter
      params.require(:resolution_result)
    end

    def track_exception_in_result(result)
      exception = resolution_result_parameter[:exception]
      return if exception.nil?

      NewRelic::Agent.notice_error(exception)
      ExceptionNotifier.notify_exception(exception)
    end

    def config_auth_token
      Figaro.env.resolution_proof_result_lambda_token
    end
  end
end
