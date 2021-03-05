module SamlIdp
  class NameIdFormatter
    attr_accessor :list
    attr_accessor :sp_name_id_format

    def initialize(list, sp_name_id_format = 'persistent')
      self.list = (list || {})
      self.sp_name_id_format = sp_name_id_format
    end

    def all
      if split?
        one_one.map { |key_val| build("1.1", key_val)[:name] } +
        two_zero.map { |key_val| build("2.0", key_val)[:name] }
      else
        list.map do |key_val|
          format_symbol = Array(key_val).first
          version = one_one_nameid_format?(format_symbol) ? '1.1' : '2.0'
          build(version, key_val)[:name]
        end
      end
    end

    def chosen
      return default_name_getter_hash unless list.key?(symbolized_name_id_format)

      version = one_one_nameid_format?(symbolized_name_id_format) ? '1.1' : '2.0'
      requested = list.find { |k, _| k == symbolized_name_id_format }

      build(version, requested)
    end

    def default_name_getter_hash
      {
        name: 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
        getter: 'id'
      }
    end

    def symbolized_name_id_format
      @symbolized_name_id_format ||= sp_name_id_format.split(':').last.underscore.to_sym
    end

    def one_one_nameid_format?(format)
      one_one_nameid_formats = %i[
        email_address
        unspecified
        windows_domain_qualified_name
        x509_subject_name
      ]

      one_one_nameid_formats.include?(format)
    end

    def build(version, key_val)
      key_val = Array(key_val)
      name = key_val.first.to_s
      getter = build_getter key_val.last || name
      name = name.camelize if %w[windows_domain_qualified_name x509_subject_name].include?(name)
      name = 'emailAddress' if name == 'email_address'

      {
        name: "urn:oasis:names:tc:SAML:#{version}:nameid-format:#{name}",
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
