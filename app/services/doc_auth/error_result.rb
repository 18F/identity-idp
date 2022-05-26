module DocAuth
  class ErrorResult
    def initialize(error = nil, side = nil)
      @error = ''
      @error_display = nil
      @sides = []
      set_error(error) unless error.nil?
      add_side(side) unless side.nil?
    end

    def set_error(error)
      @error = error
      @error_display = Errors::USER_DISPLAY[@error]
    end

    def error
      @error
    end

    def add_side(side)
      if side == :id
        @sides.push(:front, :back)
      else
        @sides << side
      end
    end

    def empty?
      @error.empty?
    end

    def to_h
      return {} if @error.empty? || @error_display.empty?
      error_output = {}

      plural_banner = @error_display[:long_msg_plural] || @error_display[:long_msg]

      error_output[:general] = [@sides.length < 2 ? @error_display[:long_msg] : plural_banner]
      @sides.each { |side| error_output[side] = [@error_display[:field_msg]] }

      error_output[:hints] = @error_display[:hints] || false

      error_output
    end
  end
end
