module LambdaCallback
  class AddressProofResultController < AuthTokenController
    def create
      dcs = DocumentCaptureSession.new
      dcs.result_id = result_id_parameter
      dcs.store_proofing_result(address_result_parameter.to_h)
    end

    private

    def result_id_parameter
      params.require(:result_id)
    end

    def address_result_parameter
      params.require(:address_result).permit(:exception, :success, :timed_out,
                                             errors: {}, context: {})
    end

    def config_auth_token
      Figaro.env.address_proof_result_lambda_token
    end
  end
end
