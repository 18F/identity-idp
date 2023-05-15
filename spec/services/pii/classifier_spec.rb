require 'rails_helper'

describe Pii::Classifier do
  let(:email) { 'test.user+dav3@example.com' }
  let(:bad_email) { 'dummy@example.com' }

  describe '#match user email when enabled' do
    it 'success on matching email' do
      expect(described_class.user_for_test_request_logging?(email)).to be(true)
    end

    it 'should fail on not matching email' do
      expect(described_class.user_for_test_request_logging?(bad_email)).to be(false)
    end

    it 'should fail on missing email' do
      expect(described_class.user_for_test_request_logging?(nil)).to be(false)
      expect(described_class.user_for_test_request_logging?('  ')).to be(false)
    end
  end

  describe 'bad regex configured' do
    before(:each) do
      allow(IdentityConfig.store).to receive(:in_person_verify_test_logging_user_email_regex).
        and_return(nil)
    end
    it 'should fail on matching email' do
      expect(described_class.user_for_test_request_logging?(email)).to be(false)
    end
  end

  describe 'test logging disabled' do
    before(:each) do
      allow(IdentityConfig.store).to receive(:in_person_verify_test_logging_enabled).
        and_return(false)
    end
    it 'should fail on match email' do
      expect(described_class.user_for_test_request_logging?(email)).to be(false)
    end
  end
end
