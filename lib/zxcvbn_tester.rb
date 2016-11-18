module Zxcvbn
  class Tester
    attr_accessor :data_path
    def initialize
      @data_path = File.expand_path("#{Rails.root}/node_modules/zxcvbn/dist/zxcvbn.js", __FILE__)
      src = File.open(@data_path || DATA_PATH, 'r').read
      @context = ExecJS.compile(src)
    end
  end
end
