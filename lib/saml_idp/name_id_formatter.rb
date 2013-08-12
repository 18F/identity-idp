module SamlIdp
  class NameIdFormatter
    attr_accessor :list
    def initialize(list)
      self.list = (list || {})
    end

    def all
      if split?
        one_one.map { |key_val| build("1.1", key_val)[:name] } +
        two_zero.map { |key_val| build("2.0", key_val)[:name] }
      else
        list.map { |key_val| build("2.0", key_val)[:name] }
      end
    end

    def chosen
      if split?
        version, choose = "1.1", one_one.first
        version, choose = "2.0", two_zero.first unless choose
        version, choose = "2.0", "persistent" unless choose
        build(version, choose)
      else
        choose = list.first || "persistent"
        build("2.0", choose)
      end
    end

    def build(version, key_val)
      key_val = Array(key_val)
      name = key_val.first.to_s.underscore
      getter = build_getter key_val.last || name
      {
        name: "urn:oasis:names:tc:SAML:#{version}:nameid-format:#{name.camelize(:lower)}",
        getter: getter
      }
    end
    private :build

    def build_getter(getter_val)
      if getter_val.respond_to?(:call)
        getter_val
      else
        ->(p) { p.public_send getter_val.to_s }
      end
    end
    private :build_getter

    def split?
      list.is_a?(Hash) && (list.key?("2.0") || list.key?("1.1"))
    end
    private :split?

    def one_one
      list["1.1"] || {}
    rescue TypeError
      {}
    end
    private :one_one

    def two_zero
      list["2.0"] || {}
    rescue TypeError
      {}
    end
    private :two_zero
  end
end
