module X509
  Attributes = Struct.new(
    :subject, :presented
  ) do
    def self.new_from_hash(hash)
      attrs = new
      hash.each { |key, val| attrs[key] = val }
      attrs
    end

    def self.new_from_json(piv_cert_json)
      return new if piv_cert_json.blank?
      piv_cert_info = JSON.parse(piv_cert_json, symbolize_names: true)
      new_from_hash(piv_cert_info)
    end

    def initialize(*args)
      super
      assign_all_members
    end

    def []=(key, value)
      if value.is_a?(Hash)
        super(key, X509::Attribute.new(value))
      else
        super(key, X509::Attribute.new(raw: value))
      end
    end

    private

    def assign_all_members
      self.class.members.each do |member|
        self[member] = self[member]
      end
    end
  end
end
