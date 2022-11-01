module UspsIppHelper
  def stub_request_token
    stub_request(:post, %r{/oauth/authenticate}).to_return(
      status: 200,
      body: UspsInPersonProofing::Mock::Fixtures.request_token_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_facilities
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getIppFacilityList}).to_return(
      status: 200,
      body: UspsInPersonProofing::Mock::Fixtures.request_facilities_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_enroll
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant}).to_return(
      status: 200,
      body: UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_enroll_bad_request_response
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant}).to_return(
      status: 400,
      body: UspsInPersonProofing::Mock::Fixtures.request_enroll_bad_request_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_enroll_internal_server_error_response
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant}).to_return(
      status: 500,
      body: UspsInPersonProofing::Mock::Fixtures.internal_server_error_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_enroll_invalid_response
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant}).to_return(
      status: 200,
      body: UspsInPersonProofing::Mock::Fixtures.request_enroll_invalid_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_expired_proofing_results
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      **request_expired_proofing_results_args,
    )
  end

  def request_expired_proofing_results_args
    {
      status: 400,
      body: UspsInPersonProofing::Mock::Fixtures.request_expired_proofing_results_response,
      headers: { 'content-type' => 'application/json' },
    }
  end

  def stub_request_failed_proofing_results
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      **request_failed_proofing_results_args,
    )
  end

  def request_failed_proofing_results_args
    {
      status: 200,
      body: UspsInPersonProofing::Mock::Fixtures.request_failed_proofing_results_response,
      headers: { 'content-type' => 'application/json' },
    }
  end

  def stub_request_failed_suspected_fraud_proofing_results
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      **request_failed_suspected_fraud_proofing_results_args,
    )
  end

  def request_failed_suspected_fraud_proofing_results_args
    {
      status: 200,
      body: UspsInPersonProofing::Mock::
        Fixtures.request_failed_suspected_fraud_proofing_results_response,
      headers: { 'content-type' => 'application/json' },
    }
  end

  def stub_request_passed_proofing_unsupported_id_results
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      status: 200,
      body: UspsInPersonProofing::Mock::
        Fixtures.request_passed_proofing_unsupported_id_results_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_passed_proofing_unsupported_status_results
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      status: 200,
      body: UspsInPersonProofing::Mock::
        Fixtures.request_passed_proofing_unsupported_status_results_response,
      headers: { 'content-type' => 'application/json' },
    )
  end

  def stub_request_passed_proofing_results
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      **request_passed_proofing_results_args,
    )
  end

  def request_passed_proofing_results_args
    {
      status: 200,
      body: UspsInPersonProofing::Mock::Fixtures.request_passed_proofing_results_response,
      headers: { 'content-type' => 'application/json' },
    }
  end

  def stub_request_in_progress_proofing_results
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      **request_in_progress_proofing_results_args,
    )
  end

  def request_in_progress_proofing_results_args
    {
      status: 400,
      body: UspsInPersonProofing::Mock::Fixtures.request_in_progress_proofing_results_response,
      headers: { 'content-type' => 'application/json' }
    }
  end

  def stub_request_proofing_results_with_timeout_error
    stub_request(
      :post,
      %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults},
    ).to_raise(Faraday::TimeoutError)
  end

  def stub_request_proofing_results_with_nil_status_error
    stub_request(
      :post,
      %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults},
    ).to_raise(Faraday::NilStatusError)
  end

  def stub_request_proofing_results_internal_server_error
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      status: 500, body: UspsInPersonProofing::Mock::Fixtures.
        internal_server_error_response
    )
  end

  def stub_request_proofing_results_with_responses(*responses)
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      responses,
    )
  end

  def stub_request_proofing_results_with_invalid_response
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults}).to_return(
      status: 200,
      body: 'invalid',
    )
  end

  def stub_request_enrollment_code
    stub_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/requestEnrollmentCode}).to_return(
      status: 200,
      body: UspsInPersonProofing::Mock::Fixtures.request_enrollment_code_response,
      headers: { 'content-type' => 'application/json' }
    )
  end
end
