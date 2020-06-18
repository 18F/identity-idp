module Acuant
  class Document < AcuantBase
    ACUANT_PASS = 1

    def call(user)
      data = wrap_network_errors { assure_id.document }
      return unless data
      pii = extract_pii(data, user)
      pii ? [data, assure_id.instance_id, pii] : nil
    end

    private

    def extract_pii(data, user)
      return unless data['Result'] == ACUANT_PASS
      Idv::Utils::PiiFromDoc.new(data).call(user&.phone_configurations&.take&.phone)
    end
  end
end
