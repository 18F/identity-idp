# Monkey-patch Propshaft::Asset to produce a shorter digest as an optimization to built output size.
#
# See: https://github.com/rails/propshaft/blob/main/lib/propshaft/asset.rb

module Extensions
  Propshaft::Asset.class_eval do
    def digest
      @digest ||= Digest::SHA1.hexdigest("#{content}#{version}")[0...7]
    end
  end
end
