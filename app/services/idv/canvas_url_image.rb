module Idv
  class CanvasUrlImage
    def initialize(canvas_url)
      @canvas_url = canvas_url
      @header = canvas_url.split(',').first
      @data = Base64.decode64(canvas_url.split(',').last)
    end

    def content_type
      @header.gsub(/^data:/, '').gsub(/;base64$/, '')
    end

    def read
      @data
    end
  end
end
