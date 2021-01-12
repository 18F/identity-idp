module LambdaCallback
  class ResolutionProofResultController < AuthTokenController
    def create
      dcs = DocumentCaptureSession.find_by(result_id: result_id_parameter)

      if dcs
        analytics.track_event(
          Analytics::LAMBDA_RESULT_RESOLUTION_PROOF_RESULT,
          result: resolution_result_parameter,
        )

        dcs.store_proofing_result(resolution_result_parameter)

        track_exception_in_result(resolution_result_parameter)
      else
        NewRelic::Agent.notice_error('ResolutionProofResult result_id not found')
        head :not_found
      end
    end

    private

    def result_id_parameter
      params.require(:result_id)
    end

    def resolution_result_parameter
      params.require(:resolution_result).permit(:exception, :success, :timed_out, :transaction_id,
                                                errors: {}, context: {})
    end

    def track_exception_in_result(result)
      exception = result[:exception]
      return if exception.nil?

      NewRelic::Agent.notice_error(exception)
      ExceptionNotifier.notify_exception(exception)
    end

    def config_auth_token
      AppConfig.env.resolution_proof_result_lambda_token
    end
  end
end
