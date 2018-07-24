module FakeAdapter
  def self.post(_endpoint, _params)
    SuccessResponse.new
  end

  class SuccessResponse
    def success?
      true
    end
  end

  class ErrorResponse
    def success?
      false
    end

    def response_body
      {
        error_code: '60033',
        message: 'Invalid number',
      }.to_json
    end

    def response_code
      400
    end
  end

  class EmptyResponse
    def success?
      false
    end

    def response_body
      ''
    end

    def response_code
      400
    end
  end
end
