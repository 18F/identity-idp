module LambdaCallback
  class DocumentProofResultController < AuthTokenController
    def create
      EncryptedRedisStructStorage.store(
        ProofingDocumentCaptureSessionResult.new(
          id: result_id_parameter,
          pii: document_result_parameter[:pii_from_doc],
          result: document_result_parameter.except(:pii_from_doc),
        ),
        expires_in: AppConfig.env.async_wait_timeout_seconds.to_i,
      )

      track_exception_in_result(document_result_parameter)
    end

    private

    def result_id_parameter
      params.require(:result_id)
    end

    def document_result_parameter
      params.require(:document_result).permit(
        :billed,
        :exception,
        :raw_alerts,
        :result,
        :success,
        :timed_out,
        context: {},
        errors: {},
        pii_from_doc: {},
        raw_alerts: [],
      )
    end

    def track_exception_in_result(result)
      exception = result[:exception]
      return if exception.nil?

      NewRelic::Agent.notice_error(exception)
      ExceptionNotifier.notify_exception(exception)
    end

    def config_auth_token
      AppConfig.env.document_proof_result_lambda_token
    end
  end
end
