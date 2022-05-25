require 'benchmark/ips'
require 'base64'
require 'uri'

module Before
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
        ''
      end
    end

    private

    def base64_encoded?
      @header.match?(BASE64_CONTENT_TYPE)
    end
  end
end

module After
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

data_url = "data:image/jpeg;base64,#{Base64.strict_encode64(File.read('dl_1_back.jpg'))}"

Benchmark.ips do |x|
  x.report('before') { Before::DataUrlImage.new(data_url).read }
  x.report('after') { After::DataUrlImage.new(data_url).read }
end
