# frozen_string_literal: true

module Idv
  class BinaryImage
    class InvalidFormatError < StandardError; end
    attr_reader :data

    def initialize(data)
      @data = data
      raise InvalidFormatError.new unless image_data?
    end

    # @return [String]
    def read
      data
    end

    private

    def image_data?
      return false if data.nil? || data.bytesize < 4

      case data[0..3].unpack1('H*')
      # the socure images are jpgs, but do we want to make this more flexible?
      when /^ffd8ff/         # JPG
        true
      when /^89504e47/       # PNG
        true
      when /^47494638/       # GIF
        true
      when /^424d/           # BMP
        true
      else
        false
      end
    end
  end
end
