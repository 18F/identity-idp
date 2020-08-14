module Idv
  class DataUrlImage
    def initialize(data_url)
      header, data = URI(data_url.chomp).opaque.to_s.split(',', 2)
      @header = header.to_s
      @data = data.to_s
    end

    BASE64_CONTENT_TYPE = /;base64$/.freeze

    # @return [String]
    def content_type
      content_type, *_rest = @header.split(';')
      content_type.to_s
    end

    # @return [String]
    def read
      if base64_encoded?
        Base64.decode64(@data)
      else
        # rubocop:disable Lint/UriEscapeUnescape
        URI.decode(@data)
        # rubocop:enable Lint/UriEscapeUnescape
      end
    end

    private

    def base64_encoded?
      !!@header.match(BASE64_CONTENT_TYPE)
    end
  end
end
