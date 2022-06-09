module Idv
  # A custom form response with additional noop methods to allow merging with DocAuth responses
  class DocAuthFormResponse < ::FormResponse
    def exception; end

    def pii_from_doc
      {}
    end

    def attention_with_barcode?
      raise NotImplementedError
    end
  end
end
