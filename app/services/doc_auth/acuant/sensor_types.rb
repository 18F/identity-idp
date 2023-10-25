# frozen_string_literal: true

module DocAuth
  module Acuant
    module SensorTypes
      UNKNOWN = '0'
      CAMERA = '1'
      SCANNER = '2'
      MOBILE = '3'

      ALL = [
        UNKNOWN,
        CAMERA,
        SCANNER,
        MOBILE,
      ].freeze
    end
  end
end
