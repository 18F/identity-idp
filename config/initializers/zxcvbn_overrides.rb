require 'zxcvbn'

module Zxcvbn
  class Tester
    attr_accessor :data_path
    def initialize
      @data_path = Rails.root.join('node_modules', 'zxcvbn', 'dist', 'zxcvbn.js')
      src = File.open(@data_path || DATA_PATH, 'r').read
      @context = ExecJS.compile(src)
    end
  end
end
