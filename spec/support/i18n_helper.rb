module I18n
  class << self
    prepend(
      Module.new do
        def t(*args, ignore_test_helper_missing_interpolation: false, **kwargs)
          result = super(*args, **kwargs)
          @ux_dumper.add_string(args[0], result)
          if ignore_test_helper_missing_interpolation ||
              !result.is_a?(String) ||
              !result.include?('%{')
            return result
          end
          raise "Missing interpolation in translated string: #{result}"
        end

        def ux_dumper=(new_value)
          @ux_dumper = new_value
        end
      end,
    )
  end
end
