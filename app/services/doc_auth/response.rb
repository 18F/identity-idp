module DocAuth
  class Response
    include ApplicationHelper

    attr_reader :errors, :exception, :extra, :pii_from_doc, :doc_type_supported,
                :selfie_live, :selfie_quality_good

    ID_TYPE_SLUGS = {
      'Identification Card' => 'state_id_card',
      'Drivers License' => 'drivers_license',
    }

    def initialize(
      success:,
      errors: {},
      exception: nil,
      extra: {},
      pii_from_doc: {},
      attention_with_barcode: false,
      doc_type_supported: true,
      selfie_check_performed: false,
      selfie_live: true,
      selfie_quality_good: true
    )
      @success = success
      @errors = errors.to_h
      @exception = exception
      @extra = extra
      @pii_from_doc = pii_from_doc
      @attention_with_barcode = attention_with_barcode
      @doc_type_supported = doc_type_supported
      @selfie_check_performed = selfie_check_performed
      @selfie_live = selfie_live
      @selfie_quality_good = selfie_quality_good
    end

    def merge(other)
      Response.new(
        success: success? && other.success?,
        errors: errors.merge(other.errors),
        exception: exception || other.exception,
        extra: extra.merge(other.extra),
        pii_from_doc: pii_from_doc.merge(other.pii_from_doc),
        attention_with_barcode: attention_with_barcode? || other.attention_with_barcode?,
        doc_type_supported: doc_type_supported? || other.doc_type_supported?,
        selfie_live: selfie_live?,
        selfie_quality_good: selfie_quality_good?,
      )
    end

    def success?
      @success
    end

    def doc_type_supported?
      @doc_type_supported
    end

    def selfie_live?
      @selfie_live
    end

    def selfie_quality_good?
      @selfie_quality_good
    end

    # We use `#to_h` to serialize this for logging. Make certain not to include
    # the `#pii` value here.
    def to_h
      {
        success: success?,
        errors: errors,
        exception: exception,
        attention_with_barcode: attention_with_barcode?,
        doc_type_supported: doc_type_supported?,
        selfie_live: selfie_live?,
        selfie_quality_good: selfie_quality_good?,
        doc_auth_success: doc_auth_success?,
        selfie_status: selfie_status,
      }.merge(extra)
    end

    def first_error_message
      return if errors.blank?
      _key, message_or_messages = errors.first
      Array(message_or_messages).first
    end

    def attention_with_barcode?
      @attention_with_barcode
    end

    def network_error?
      return false unless @errors
      return !!@errors&.with_indifferent_access&.dig(:network)
    end

    def selfie_check_performed?
      @selfie_check_performed
    end

    def doc_auth_success?
      # to be implemented by concrete subclass
      false
    end

    def selfie_status
      # to be implemented by concrete subclass
      :not_processed
    end
  end
end
