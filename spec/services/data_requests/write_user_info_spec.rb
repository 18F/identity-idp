require 'rails_helper'

describe DataRequests::WriteUserInfo do
  describe '#call' do
    it 'writes a file with user information' do
      user_report = JSON.parse(
        File.read('spec/fixtures/data_request.json'), symbolize_names: true
      ).first

      Dir.mktmpdir do |dir|
        described_class.new(user_report, dir).call
        user = File.read(File.join(dir, 'user.csv'))
        headings = user.split("\n\n").map do |info_group|
          info_group.split("\n").first
        end

        expect(headings).to include('Emails:')
        expect(headings).to include('Phone configurations:')
        expect(headings).to include('Auth app configurations:')
        expect(headings).to include('WebAuthn configurations:')
        expect(headings).to include('PIV/CAC configurations:')
        expect(headings).to include('Backup code configurations:')
      end
    end
  end
end
