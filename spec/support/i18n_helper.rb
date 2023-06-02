module I18n
  class << self
    prepend(
      Module.new do
        def t(...)
          result = super(...)

          if result.include?('%{')
            raise "Unexpected missing interpolation in translated string: #{result}"
          end

          result
        end
      end,
    )
  end
end
