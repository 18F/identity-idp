require 'spec_helper'
require 'pwned_password_downloader'
require 'tempfile'

RSpec.describe PwnedPasswordDownloader do
  subject(:downloader) do
    PwnedPasswordDownloader.new(
      destination: @destination,
      output_progress: false,
      keep_threshold: 5,
    )
  end

  around do |example|
    Dir.mktmpdir('pwned_passwords') do |destination|
      @destination = destination
      example.run
    end
  end

  before do
    stub_request(:get, URI.join(PwnedPasswordDownloader::RANGE_API_ROOT, '00000').to_s).to_return(
      body: <<~BODY,
        0005AD76BD555C1D6D771DE417A4B87E4B4:10
        000A8DAE4228F821FB418F59826079BF368:4
        03643C928B2BCD37475C574E6F31B4650AD:22
      BODY
    )
    stub_request(:get, URI.join(PwnedPasswordDownloader::RANGE_API_ROOT, '00001').to_s).
      to_return(body: '00C271B56ABE9E5C137217BF2DE657C7B2F:5')
    allow(downloader).to receive(:wait_for_progress)
  end

  describe '#run!' do
    let(:start) { '00000' }
    let(:finish) { '00001' }
    subject(:run) { downloader.run!(start:, finish:) }

    it 'downloads the given range' do
      run

      expect(Dir.entries(@destination)).to eq(['.', '..', '00000', '00001'])
      expect(File.readlines(File.join(@destination, '00000'))).to eq [
        "000000005AD76BD555C1D6D771DE417A4B87E4B4:10\n",
        "0000003643C928B2BCD37475C574E6F31B4650AD:22\n",
      ]
      expect(File.readlines(File.join(@destination, '00001'))).to eq [
        "0000100C271B56ABE9E5C137217BF2DE657C7B2F:5\n",
      ]
    end
  end
end
