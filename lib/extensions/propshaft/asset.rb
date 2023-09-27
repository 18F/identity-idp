module Extensions
  Propshaft::Asset.class_eval do
    def digest
      @digest ||= Digest::SHA1.hexdigest("#{content}#{version}")[0...7]
    end
  end
end
