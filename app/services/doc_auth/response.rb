module DocAuth
  class Response
    attr_reader :errors, :exception, :extra, :pii_from_doc

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
      attention_with_barcode: false
    )
      @success = success
      @errors = errors.to_h
      @exception = exception
      @extra = extra
      @pii_from_doc = pii_from_doc
      @attention_with_barcode = attention_with_barcode
    end

    def merge(other)
      Response.new(
        success: success? && other.success?,
        errors: errors.merge(other.errors),
        exception: exception || other.exception,
        extra: extra.merge(other.extra),
        pii_from_doc: pii_from_doc.merge(other.pii_from_doc),
        attention_with_barcode: attention_with_barcode? || other.attention_with_barcode?,
      )
    end

    def success?
      @success
    end

    # We use `#to_h` to serialize this for logging. Make certain not to include
    # the `#pii` value here.
    def to_h
      {
        success: success?,
        errors: errors,
        exception: exception,
        attention_with_barcode: attention_with_barcode?,
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
  end
end
