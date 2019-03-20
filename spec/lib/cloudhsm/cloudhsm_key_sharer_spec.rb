require 'rails_helper'
require 'cloudhsm/cloudhsm_key_sharer'

describe CloudhsmKeySharer do
  let(:saml_label) { 'saml_20180614001957' }
  let(:subject) { CloudhsmKeySharer.new(saml_label) }
  let(:key_handle) { '1234' }
  let(:key_owner_name) { 'username' }
  let(:key_owner_password) { 'password' }
  let(:shared_with_username) { 'username2' }
  let(:shared_with_user_id) { '4' }
  let(:transcript_fn) { "#{saml_label}.shr" }

  describe '#share_saml_key' do
    it 'shares saml key and generates transcript' do
      allow(Kernel).to receive(:puts)

      greenletters = mock_cloudhsm

      subject.share_saml_key

      expect(greenletters).to have_received(:<<).with("enable_e2e\n").once
      expect(greenletters).to have_received(:<<).
        with("loginHSM CU #{key_owner_name} #{key_owner_password}\n").once
      expect(greenletters).to have_received(:<<).with("listUsers\n").once
      expect(greenletters).to have_received(:<<).
        with("shareKey #{key_handle} #{shared_with_user_id} 1\n").once
      expect(greenletters).to have_received(:<<).with("y\n").once
      expect(greenletters).to have_received(:<<).with("quit\n").once
      expect(File.exist?(transcript_fn)).to eq(true)

      File.delete(transcript_fn)
    end

    it 'raises an error if the user is not found in listUsers' do
      greenletters = mock_cloudhsm
      allow(greenletters).to receive(:wait_for).with(:output, /\d+\s+CU\s+#{shared_with_username}/).
        and_return(false)

      expect { subject.share_saml_key }.
        to raise_error(RuntimeError, "User #{shared_with_username} not found")
    end
  end

  def mock_cloudhsm
    greenletters = instance_double(Greenletters::Process)
    allow(Greenletters::Process).to receive(:new).and_return(greenletters)

    allow(greenletters).to receive(:<<).and_return(true)
    allow(greenletters).to receive(:start!).and_return(true)
    allow(greenletters).to receive(:wait_for).and_return(true)
    allow(greenletters).to receive(:wait_for).with(:output, /\d+\s+CU\s+#{shared_with_username}/).
      and_yield(nil, StringScanner.new(''))

    allow_any_instance_of(StringScanner).to receive(:matched).
      and_return("#{shared_with_user_id} CU #{shared_with_username} NO 0 NO\n")

    allow(File).to receive(:read).with("#{saml_label}.scr").
      and_return("#{key_owner_name}:#{key_owner_password}:#{key_handle}:#{shared_with_username}")

    greenletters
  end
end
