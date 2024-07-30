module I18n
  class << self
    prepend(
      Module.new do
        def t(*args, ignore_test_helper_missing_interpolation: false, **kwargs)
          result = super(*args, **kwargs)
          if ignore_test_helper_missing_interpolation ||
              !result.is_a?(String) ||
              !result.include?('%{')
            return result
          end
          raise "Missing interpolation in translated string: #{result}"
        end
      end,
    )
  end
end
