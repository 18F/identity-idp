module LambdaCallback
  class AddressProofResultController < AuthTokenController
    def create
      dcs = DocumentCaptureSession.new
      dcs.result_id = result_id_parameter
      dcs.store_proofing_result(nil, address_result_parameter)
    end

    private

    def result_id_parameter
      params.require(:result_id)
    end

    def address_result_parameter
      params.require(:address_result)
    end

    def config_auth_token
      Figaro.env.address_proof_result_lambda_token
    end
  end
end
