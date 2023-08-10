module DocAuth
  module Acuant
    module ClassificationConcern
      extend ActiveSupport::Concern

      # check whether doc type is supported, return false only if classification info clearly
      # identifies the document type and that document type is not a supported one
      def id_type_supported?
        info = classification_info
        return true if info.nil?
        doc_side_class_ok?(info, 'Front') && doc_side_class_ok?(info, 'Back')
      end

      private

      # @param [Object] classification_info assureid classification info
      # @param [String] doc_side value of ['Front', 'Back']
      def doc_side_class_ok?(classification_info, doc_side)
        side_type = classification_info&.dig(doc_side, 'ClassName')
        !side_type.present? || DocAuth::Response::ID_TYPE_SLUGS.key?(side_type) ||
          side_type == 'Unknown'
      end
    end
  end
end
