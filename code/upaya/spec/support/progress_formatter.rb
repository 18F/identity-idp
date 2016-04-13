RSpec::Support.require_rspec_core 'formatters/base_text_formatter'

module RSpec
  module Core
    module Formatters
      # @private
      class ProgressFormatter < BaseTextFormatter
        Formatters.register self, :example_passed, :example_pending, :example_failed, :start_dump

        def example_passed(_notification)
          output.print ConsoleCodes.wrap("\u2665", :success)
        end

        def example_pending(_notification)
          output.print ConsoleCodes.wrap("\u23F3 ", :pending)
        end

        def example_failed(_notification)
          output.print ConsoleCodes.wrap("\u2620 ", :failure)
        end

        def start_dump(_notification)
          output.puts
        end
      end
    end
  end
end
