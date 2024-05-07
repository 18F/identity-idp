# frozen_string_literal: true

module Idv
  # A custom form response with additional noop methods to allow merging with DocAuth responses
  class DocAuthFormResponse < ::FormResponse
    attr_writer :pii_from_doc

    def exception; end

    def pii_from_doc
      @pii_from_doc || {}
    end

    def attention_with_barcode?
      extra[:attention_with_barcode].present?
    end
  end
end
