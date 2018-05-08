require 'stringex/unidecoder'
require 'stringex/core_ext'

module X509
  class Attribute
    attr_accessor :raw, :norm

    def initialize(raw: nil, norm: nil)
      @raw = raw
      @norm = norm
    end

    delegate :blank?, :present?, :to_s, :to_date, :==, :eql?, to: :raw
    alias to_str to_s
  end
end
