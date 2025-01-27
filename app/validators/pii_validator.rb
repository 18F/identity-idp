# frozen_string_literal: true

module Idv
  class PiiValidator
    def initialize(client_response, extra, analytics)
      @client_response = client_response
      @extra = extra
      @analytics = analytics
    end

    def doc_auth_form_response
      return @doc_auth_form_response if @doc_auth_form_response

      @doc_auth_form_response = Idv::DocPiiForm.new(
        pii: client_response.pii_from_doc.to_h,
        attention_with_barcode: client_response.attention_with_barcode?,
      ).submit

      @doc_auth_form_response.extra.merge!(extra)

      analytics.idv_doc_auth_submitted_pii_validation(**response_with_classification)

      @doc_auth_form_response
    end

    def success?
      doc_auth_form_response.success?
    end

    private

    attr_reader :client_response, :extra, :analytics

    def response_with_classification
      doc_auth_form_response.to_h.merge(doc_side_classification)
    end

    def doc_side_classification
      side_info = {}.merge(client_response&.extra&.[](:classification_info) || {})
      side_info.transform_keys(&:downcase).symbolize_keys
      {
        classification_info: side_info,
      }
    end
  end
end
