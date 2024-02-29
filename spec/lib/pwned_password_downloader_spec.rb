require 'spec_helper'
require 'pwned_password_downloader'
require 'tempfile'

RSpec.describe PwnedPasswordDownloader do
  let(:destination) { Dir.mktmpdir('pwned_passwords') }
  subject(:downloader) { PwnedPasswordDownloader.new(destination:) }

  before do
    stub_request(:get, URI.join(PwnedPasswordDownloader::RANGE_API_ROOT, '00000').to_s).to_return(
      body: "0005AD76BD555C1D6D771DE417A4B87E4B4:10\r\n000A8DAE4228F821FB418F59826079BF368:4",
    )
    stub_request(:get, URI.join(PwnedPasswordDownloader::RANGE_API_ROOT, '00001').to_s).
      to_return(body: '0005DE2A9668A41F6A508AFB6A6FC4A5610:1')
    allow(Thread).to receive(:new).and_yield(rand.to_s)
    allow(downloader).to receive(:queue).and_return([])
    allow(downloader).to receive(:wait_for_progress)
    allow(downloader).to receive(:progress_bar).and_return(
      double(ProgressBar, increment: nil, stop: nil),
    )
  end

  describe '#run!' do
    let(:start) { '00000' }
    let(:finish) { '00001' }
    subject(:run) { downloader.run!(start:, finish:) }

    it 'downloads the given range' do
      run

      expect(Dir.entries(destination)).to eq(['.', '..', '00000', '00001'])
    end
  end
end
