module LambdaCallback
  class DocumentProofResultController < AuthTokenController
    def create
      dcs = DocumentCaptureSession.find_by(result_id: result_id_parameter)

      if dcs
        dcs.store_doc_auth_result(
          result: document_result_parameter.except(:pii_from_doc),
          pii: document_result_parameter[:pii_from_doc],
        )

        track_exception_in_result(document_result_parameter)
      else
        NewRelic::Agent.notice_error('DocumentProofResult result_id not found')
        head :not_found
      end
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
