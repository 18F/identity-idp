module UspsInPersonProofing
  class Proofer
    attr_reader :token, :token_expires_at

    # Makes HTTP request to get nearby in-person proofing facilities
    # Requires address, city, state and zip code.
    # The PostOffice objects have a subset of the fields
    # returned by the API.
    # @param location [Object]
    # @return [Array<PostOffice>] Facility locations
    def request_facilities(location)
      url = "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/getIppFacilityList"
      body = {
        sponsorID: sponsor_id,
        streetAddress: location.address,
        city: location.city,
        state: location.state,
        zipCode: location.zip_code,
      }.to_json

      headers = request_headers.merge(
        'Authorization' => @token,
        'RequestID' => request_id,
      )

      parse_facilities(
        faraday.post(url, body, headers) do |req|
          req.options.context = { service_name: 'usps_facilities' }
        end.body,
      )
    end

    # Temporary function to return a static set of facilities
    # @return [Array<PostOffice>] Facility locations
    def request_pilot_facilities
      resp = File.read(Rails.root.join('config', 'ipp_pilot_usps_facilities.json'))
      parse_facilities(JSON.parse(resp))
    end

    # Makes HTTP request to enroll an applicant in in-person proofing.
    # Requires first name, last name, address, city, state, zip code, email address and a generated
    # unique ID. The unique ID must be no longer than 18 characters.
    # USPS sends an email to the email address with instructions and the enrollment code.
    # The API response also includes the enrollment code which should be
    # stored with the unique ID to be able to request the status of proofing.
    # @param applicant [Object]
    # @return [Hash] API response
    def request_enroll(applicant)
      url = "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant"
      body = {
        sponsorID: sponsor_id,
        uniqueID: applicant.unique_id,
        firstName: applicant.first_name,
        lastName: applicant.last_name,
        streetAddress: applicant.address,
        city: applicant.city,
        state: applicant.state,
        zipCode: applicant.zip_code,
        emailAddress: applicant.email,
        IPPAssuranceLevel: '1.5',
      }

      res = faraday.post(url, body, dynamic_headers) do |req|
        req.options.context = { service_name: 'usps_enroll' }
      end
      Response::RequestEnrollResponse.new(res.body)
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
      url = "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults"
      body = {
        sponsorID: sponsor_id,
        uniqueID: unique_id,
        enrollmentCode: enrollment_code,
      }

      faraday.post(url, body, dynamic_headers) do |req|
        req.options.context = { service_name: 'usps_proofing_results' }
      end.body
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
      }

      faraday.post(url, body, dynamic_headers) do |req|
        req.options.context = { service_name: 'usps_enrollment_code' }
      end.body
    end

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

    private

    def faraday
      Faraday.new(headers: request_headers) do |conn|
        conn.options.timeout = IdentityConfig.store.usps_ipp_request_timeout
        conn.options.read_timeout = IdentityConfig.store.usps_ipp_request_timeout
        conn.options.open_timeout = IdentityConfig.store.usps_ipp_request_timeout
        conn.options.write_timeout = IdentityConfig.store.usps_ipp_request_timeout

        # Log request metrics
        conn.request :instrumentation, name: 'request_metric.faraday'

        # Raise an error subclassing Faraday::Error on 4xx, 5xx, and malformed responses
        # Note: The order of this matters for parsing the error response body.
        conn.response :raise_error

        # Convert body to JSON
        conn.request :json

        # Parse JSON responses
        conn.response :json
      end
    end

    # Retrieve the OAuth2 token (if needed) and then pass
    # the headers to an arbitrary block of code as a Hash.
    #
    # Returns the same value returned by that block of code.
    def dynamic_headers
      retrieve_token! unless token_valid?

      {
        'Authorization' => @token,
        'RequestID' => request_id,
      }
    end

    # Makes HTTP request to authentication endpoint and
    # returns the token and when it expires (15 minutes).
    # @return [Hash] API response
    def request_token
      url = "#{root_url}/oauth/authenticate"
      body = {
        username: IdentityConfig.store.usps_ipp_username,
        password: IdentityConfig.store.usps_ipp_password,
        grant_type: 'implicit',
        response_type: 'token',
        client_id: IdentityConfig.store.usps_ipp_client_id,
        scope: 'ivs.ippaas.apis',
      }

      faraday.post(url, body) do |req|
        req.options.context = { service_name: 'usps_token' }
      end.body
    end

    def root_url
      IdentityConfig.store.usps_ipp_root_url
    end

    def sponsor_id
      IdentityConfig.store.usps_ipp_sponsor_id.to_i
    end

    def request_id
      SecureRandom.uuid
    end

    def request_headers
      { 'Content-Type' => 'application/json; charset=utf-8' }
    end

    def parse_facilities(facilities)
      facilities['postOffices'].map do |post_office|
        hours = {}
        post_office['hours'].each do |hour_details|
          hour_details.keys.each do |key|
            hours[key] = hour_details[key]
          end
        end

        PostOffice.new(
          address: post_office['streetAddress'],
          city: post_office['city'],
          distance: post_office['distance'],
          name: post_office['name'],
          phone: post_office['phone'],
          saturday_hours: hours['saturdayHours'],
          state: post_office['state'],
          sunday_hours: hours['sundayHours'],
          weekday_hours: hours['weekdayHours'],
          zip_code_4: post_office['zip4'],
          zip_code_5: post_office['zip5'],
        )
      end
    end
  end
end
