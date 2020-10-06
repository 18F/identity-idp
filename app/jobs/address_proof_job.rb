class AddressProofJob
  def self.handle(event:, context: _, &callback)
    body = JSON.parse(event[:body])
    applicant_pii = body['applicant_pii']
    callback_url = body['callback_url']

    idv_result = Idv::Agent.new(applicant_pii).proof_address

    if block_given?
      callback.call(idv_result)
    else
      callback_body = {
        address_result: idv_result.to_h,
      }

      Faraday.post(
        callback_url,
        callback_body.to_json,
        'X-API-AUTH-TOKEN' => Figaro.env.address_proof_result_lambda_token,
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
      )
    end
  end
end
