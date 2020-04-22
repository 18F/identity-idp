module Acuant
  class AcuantBase
    def initialize(instance_id = nil)
      assure_id.instance_id = instance_id if instance_id
    end

    private

    def wrap_network_errors
      request_successful, data = yield
      data = parse_if_json(data)
      request_successful ? data : nil
    end

    def parse_if_json(data)
      JSON.parse(data)
    rescue JSON::ParserError
      data
    end

    def assure_id
      @assure_id ||= new_assure_id
    end

    def new_assure_id
      (Rails.env.test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::AssureId).new
    end
  end
end
