require 'spec_helper'
require 'upaya_log_formatter'

RSpec.describe Upaya::UpayaLogFormatter do
  describe '.call' do
    it 'prints expected standard messages' do
      now = Time.utc(2019, 1, 2, 3, 4, 5)
      expect(Upaya::UpayaLogFormatter.new.call('INFO', now, 'progname', 'hello')).to eq(
        "I, [2019-01-02T03:04:05.000000 ##{Process.pid}]  INFO -- progname: hello\n",
      )
    end

    it 'prints JSON-like messages as-is' do
      expect(
        Upaya::UpayaLogFormatter.new.call('INFO', Time.zone.now, 'progname', '{"hello"}'),
      ).to eq('{"hello"}' + "\n")
    end
  end
end

describe Upaya::DevelopmentUpayaLogFormatter do
  describe '.call' do
    it 'prints ANSI escaped messages as-is' do
      now = Time.utc(2019, 1, 2, 3, 4, 5)
      msg = "\e[1;31mhello\e[m"
      expect(Upaya::DevelopmentUpayaLogFormatter.new.call('INFO', now, 'progname', msg)).to eq(
        msg + "\n",
      )
    end

    it 'prints expected messages otherwise' do
      now = Time.utc(2019, 1, 2, 3, 4, 5)
      expect(Upaya::DevelopmentUpayaLogFormatter.new.call('INFO', now, 'progname', 'hello')).to eq(
        "I, [2019-01-02T03:04:05.000000 ##{Process.pid}]  INFO -- progname: hello\n",
      )
    end
  end
end
