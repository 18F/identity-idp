module SamlIdp
  class NameIdFormatter
    attr_accessor :list
    def initialize(list)
      self.list = list.is_a?(Hash) ? list : Array(list)
    end

    def samlize
      if split?
        one_one.map { |el| "urn:oasis:names:tc:SAML:1.1:nameid-format:#{el.to_s.camelize(:lower)}" } +
        two_zero.map { |el| "urn:oasis:names:tc:SAML:2.0:nameid-format:#{el.to_s.camelize(:lower)}" }
      else
        list.map { |el| "urn:oasis:names:tc:SAML:2.0:nameid-format:#{el.to_s.camelize(:lower)}" }
      end
    end

    def split?
      list.is_a?(Hash)
    end
    private :split?

    def one_one
      Array(list["1.1"])
    end
    private :one_one

    def two_zero
      Array(list["2.0"])
    end
    private :two_zero
  end
end
