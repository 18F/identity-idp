require 'rails_helper'

describe Idv::Utils::ImagesToTmpFiles do
  let(:images) { %w[abc def] }
  let(:subject) { Idv::Utils::ImagesToTmpFiles.new(*images) }

  describe '#call' do
    it 'creates temporary files for the images' do
      save_paths = []
      subject.call do |tmp_fns|
        save_paths << tmp_fns[0].path
        save_paths << tmp_fns[1].path
        expect(File.read(tmp_fns[0])).to eq('abc')
        expect(File.read(tmp_fns[1])).to eq('def')
      end

      expect(File.exist?(save_paths[0])).to eq(false)
      expect(File.exist?(save_paths[1])).to eq(false)
    end
  end
end
