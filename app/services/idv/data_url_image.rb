module Idv
  class DataUrlImage
    class InvalidUrlFormatError < StandardError; end

    def initialize(data_url)
      header_and_data = data_url.delete_prefix('data:')
      raise InvalidUrlFormatError.new if header_and_data == data_url
      header, data = header_and_data.split(',', 2)
      @header = header
      @data = data
    end

    # @return [String]
    def read
      if base64_encoded?
        Base64.decode64(@data)
      else
        Addressable::URI.unencode(@data)
      end
    end

    private

    def base64_encoded?
      @header.end_with?(';base64')
    end
  end
end
