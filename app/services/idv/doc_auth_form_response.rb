module Idv
  # A custom form response with additional noop methods to allow merging with DocAuth responses
  class DocAuthFormResponse < ::FormResponse
    attr_accessor :pii_from_doc

    def exception; end

    def attention_with_barcode?
      extra[:attention_with_barcode].present?
    end

    def merge(other)
      merged = super
      merged.pii_from_doc = other.pii_from_doc if other.respond_to? :pii_from_doc
      merged.pii_from_doc ||= pii_from_doc
      merged
    end
  end
end
