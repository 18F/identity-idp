module Idv
  class DataUrlImage
    class InvalidUrlFormatError < StandardError; end

    attr_reader :content_type

    def initialize(data_url)
      header_and_data = data_url.delete_prefix('data:')
      raise InvalidUrlFormatError.new if header_and_data == data_url
      header, data = header_and_data.split(',', 2)
      content_type, encoding = header.split(';', 2)

      @content_type = content_type
      @base64_encoded = encoding == 'base64'
      @data = data
    end

    # @return [String]
    def read
      if @base64_encoded
        Base64.decode64(@data)
      else
        Addressable::URI.unencode(@data)
      end
    end
  end
end
