module Acuant
  class Instance < AcuantBase
    def call
      wrap_network_errors { assure_id.create_document }
    end
  end
end
