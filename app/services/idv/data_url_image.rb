module Idv
  class DataUrlImage
    def initialize(data_url)
      header_and_data = data_url.delete_prefix('data:')
      if (header_and_data == data_url)
        header, data = '', ''
      else
        header, data = header_and_data.split(',', 2)
      end
      @header = header
      @data = data
    end

    # @return [String]
    def content_type
      @header.split(';', 2).first.to_s
    end

    # @return [String]
    def read
      if base64_encoded?
        Base64.decode64(@data)
      else
        ''
      end
    end

    private

    def base64_encoded?
      @header.end_with?(';base64')
    end
  end
end
