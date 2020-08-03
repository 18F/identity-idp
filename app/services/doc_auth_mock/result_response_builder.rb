module DocAuthMock
  class ResultResponseBuilder
    DEFAULT_PII_FROM_DOC = {
      first_name: 'FAKEY',
      middle_name: nil,
      last_name: 'MCFAKERSON',
      address1: '1 FAKE RD',
      address2: nil,
      city: 'GREAT FALLS',
      state: 'MT',
      zipcode: '59010',
      dob: '10/06/1938',
      state_id_number: '1111111111111',
      state_id_jurisdiction: 'ND',
      state_id_type: 'drivers_license',
      phone: nil,
    }.freeze

    attr_reader :uploaded_file

    def initialize(uploaded_file)
      @uploaded_file = uploaded_file.to_s
    end

    def call
      DocAuthMock::Responses::GetResultsResponse.new(
        success: success?,
        errors: errors,
        pii_from_doc: pii_from_doc,
        billed: true,
      )
    end

    private

    def errors
      return [] if parsed_yaml_from_uploaded_file.blank?
      [parsed_yaml_from_uploaded_file['friendly_error']].compact
    end

    def parsed_yaml_from_uploaded_file
      @parsed_yaml_from_uploaded_file ||= begin
                                            YAML.safe_load(uploaded_file)
                                          rescue Psych::SyntaxError
                                            nil
                                          end
    end

    def pii_from_doc
      return DEFAULT_PII_FROM_DOC if parsed_yaml_from_uploaded_file.blank?
      raw_pii = parsed_yaml_from_uploaded_file['document']
      raw_pii&.symbolize_keys || {}
    end

    def success?
      errors.none?
    end
  end
end
