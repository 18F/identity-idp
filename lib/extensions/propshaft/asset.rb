module Extensions
  Propshaft::Asset.class_eval do
    alias_method :original_digest, :digest

    def digest
      @digest ||= original_digest[0...7]
    end
  end
end
