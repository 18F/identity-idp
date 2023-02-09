module UspsInPersonProofing
    class EnrollmentValidator
        def initialize
            @additional_unsupported_chars = {
                first_name: /[^A-Za-z\-' ]/,
                last_name: /[^A-Za-z\-' ]/,
                address1: /[^A-Za-z0-9\-' .\/#]/,
                address2: /[^A-Za-z0-9\-' .\/#]/,
                city: /[^A-Za-z\-' ]/,
            }
        end

        # @param [Hash] fields
        def validate(fields)
            fields.slice({
                :first_name,
                :last_name,
                :address1,
                :address2,
                :city,
            }).compact.each do |key, value|
                result = transliterator.transliterate(value)
                result.transliterated.scan(/[^A-Za-z0-9\-' .\/#]/)
                # todo
                # result.unsupported_chars.
            end
        end

        private

        def transliterator
            transliterator ||= Transliterator.new
        end
    end
end