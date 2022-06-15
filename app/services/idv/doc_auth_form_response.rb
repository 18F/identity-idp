module Idv
  # A custom form response with additional noop methods to allow merging with DocAuth responses
  class DocAuthFormResponse < ::FormResponse
    attr_accessor :ocr_pii

    def exception; end

    def pii_from_doc
      {}
    end

    def merge(other)
      merged = super
      merged.ocr_pii = other.ocr_pii if other.respond_to? :ocr_pii
      merged.ocr_pii ||= ocr_pii
      merged
    end
  end
end
