# frozen_string_literal: true

require 'ruby-progressbar'

module Reporting
  # Small wrapper around ruby-progressbar
  class UnknownProgressBar
    # Wraps a block and displays a progress bar while the block executes
    # Returns the value from the block
    def self.wrap(show_bar:, title: 'Waiting', output: STDERR)
      if show_bar
        bar = ProgressBar.create(
          title: title,
          total: nil,
          format: '[ %t ] %B %a',
          output: output,
        )
        thread = Thread.fork do
          loop do
            sleep 0.1
            bar.increment
          end
        end
      end

      yield
    ensure
      thread&.kill
      bar&.stop
    end
  end
end
