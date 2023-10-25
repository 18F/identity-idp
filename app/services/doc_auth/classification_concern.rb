# frozen_string_literal: true

module DocAuth
  module ClassificationConcern
    extend ActiveSupport::Concern
    # check whether doc type is supported, return false only if classification info clearly
    # identifies the document type and that document type is not a supported one
    def id_type_supported?
      info = classification_info
      return true if info.nil?
      type_ok = doc_side_class_ok?(info, 'Front') && doc_side_class_ok?(info, 'Back')
      issuing_country_ok = doc_issuing_country_ok?(
        info,
        'Front',
      ) && doc_issuing_country_ok?(info, 'Back')
      type_ok && issuing_country_ok
    end

    alias_method :doc_type_supported?, :id_type_supported?

  private

    # @param [Object] classification_info assureid classification info
    # @param [String] doc_side value of ['Front', 'Back']
    def doc_side_class_ok?(classification_info, doc_side)
      side_type = classification_info&.with_indifferent_access&.dig(doc_side, 'ClassName')
      !side_type&.present? ||
        DocAuth::Response::ID_TYPE_SLUGS.key?(side_type) ||
        side_type == 'Unknown'
    end

    # @param [Object] classification_info assureid classification info
    # @param [String] doc_side value of ['Front', 'Back']
    def doc_issuing_country_ok?(classification_info, doc_side)
      side_country = classification_info&.with_indifferent_access&.dig(doc_side, 'CountryCode')
      !side_country&.present? ||
        supported_country_codes.include?(side_country)
    end

    def supported_country_codes
      IdentityConfig.store.doc_auth_supported_country_codes
    end
end
end
