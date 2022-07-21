module UspsInPersonProofing
  module Mock
    class Proofer
      # todo: update the documentation for these methods
      attr_reader :token, :token_expires_at

      # Makes a request to retrieve a new OAuth token
      # and modifies self to store the token and when
      # it expires (15 minutes).
      # @return [String] the token
      def retrieve_token!
        body = request_token
        @token_expires_at = Time.zone.now + body['expires_in']
        @token = "#{body['token_type']} #{body['access_token']}"
      end

      def token_valid?
        @token.present? && @token_expires_at.present? && @token_expires_at.future?
      end

      # Makes HTTP request to authentication endpoint
      # and modifies self to store the token and when
      # it expires (15 minutes).
      # @return [Hash] API response
      def request_token
        JSON.load_file(
          Rails.root.join('spec/fixtures/usps_ipp_responses/request_token_response.json'),
        )
      end

      # Makes HTTP request to get nearby in-person proofing facilities
      # Requires address, city, state and zip code.
      # The PostOffice objects have a subset of the fields
      # returned by the API.
      # @param location [Object]
      # @return [Array<PostOffice>] Facility locations
      def request_facilities(location)
        # todo: return constant list
      end

      # Makes HTTP request to enroll an applicant in in-person proofing.
      # Requires first name, last name, address, city, state, zip code, email address and a
      # generated unique ID. The unique ID must be no longer than 18 characters.
      # USPS sends an email to the email address with instructions and the enrollment code.
      # The API response also includes the enrollment code which should be
      # stored with the unique ID to be able to request the status of proofing.
      # @param applicant [Object]
      # @return [Hash] API response
      def request_enroll(_applicant)
        # todo: return fake results here, including test error cases
        JSON.load_file(
          Rails.root.join('spec/fixtures/usps_ipp_responses/request_enroll_response.json'),
        )
      end

      # Makes HTTP request to retrieve proofing status
      # Requires the applicant's enrollment code and unique ID.
      # When proofing is complete the API returns 200 status.
      # If the applicant has not been to the post office, has proofed recently,
      # or there is another issue, the API returns a 400 status with an error message.
      # @param unique_id [String]
      # @param enrollment_code [String]
      # @return [Hash] API response
      def request_proofing_results(unique_id, enrollment_code)
        # todo: mock this somehow, maybe not right now though
        url = "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults"
        body = {
          sponsorID: sponsor_id,
          uniqueID: unique_id,
          enrollmentCode: enrollment_code,
        }.to_json

        headers = request_headers.merge(
          {
            'Authorization' => @token,
            'RequestID' => request_id,
          },
        )

        resp = faraday.post(url, body, headers)

        if resp.success?
          JSON.parse(resp.body)
        elsif resp.status == 400 && resp.headers['content-type'] == 'application/json'
          JSON.parse(resp.body)
        else
          { error: 'failed to get proofing results', response: resp }
        end
      end

      # Makes HTTP request to retrieve enrollment code
      # If an applicant has a currently valid enrollment code, it will be returned.
      # If they do not, a new one will be generated and returned. USPS sends the applicant an email
      # with instructions and the enrollment code.
      # Requires the applicant's unique ID.
      # @param unique_id [String]
      # @return [Hash] API response
      def request_enrollment_code(unique_id)
        url = "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/requestEnrollmentCode"
        body = {
          sponsorID: sponsor_id,
          uniqueID: unique_id,
        }.to_json

        headers = request_headers.merge(
          {
            'Authorization' => @token,
            'RequestID' => request_id,
          },
        )

        resp = faraday.post(url, body, headers)

        if resp.success?
          JSON.parse(resp.body)
        else
          resp
        end
      end

      def sponsor_id
        IdentityConfig.store.usps_ipp_sponsor_id.to_i
      end

      def request_id
        SecureRandom.uuid
      end
    end
  end
end
