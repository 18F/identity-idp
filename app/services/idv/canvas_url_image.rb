module Idv
  class CanvasUrlImage
    def initialize(canvas_url)
      @header, base64_data = canvas_url.split(',', 2)
      @data = Base64.decode64(base64_data || '')
    end

    def content_type
      @header.gsub(/^data:/, '').gsub(/;base64$/, '')
    end

    def read
      @data
    end
  end
end
