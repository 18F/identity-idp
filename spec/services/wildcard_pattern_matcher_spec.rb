require 'rails_helper'

describe WildcardPatternMatcher do
  describe '#match?' do
    it 'matches with no wildcard' do
      expect(match?("idp.dev.login.gov","idp.dev.login.gov")).to eq true
    end
    it 'does not match without a wildcard' do
      expect(match?("idp.dev.login.gov","idp.int.login.gov")).to eq false
    end
    it 'matches wildcard at the beginning' do
      expect(match?("*.login.gov","idp.dev.login.gov")).to eq true
    end
    it 'does not match wildcard at the beginning' do
      expect(match?("*.login.gov","login.gov")).to eq false
    end
    it 'matches wildcard at the end' do
      expect(match?("login.gov/*","login.gov/foo")).to eq true
    end
    it 'does not match with wildcard at the end' do
      expect(match?("login.gov/*","login.gov.ru/foo")).to eq false
    end
    it 'matches blank for wildcard' do
      expect(match?("login.gov/*","login.gov/")).to eq true
    end
    it 'matches array with wildcards' do
      expect(match?(["idp.*.login.gov","idp.*.identitysandbox.gov"],"idp.qa.identitysandbox.gov")).to eq true
    end
    it 'does not match array with wildcards' do
      expect(match?(["idp.*.login.gov","idp.*.identitysandbox.gov"],"gov")).to eq false
    end
    it 'matches array with no wildcards' do
      expect(match?(["idp.qa.login.gov","idp.qa.identitysandbox.gov"],"idp.qa.identitysandbox.gov")).to eq true
    end
    it 'does not match array with no wildcards' do
      expect(match?(["idp.qa.login.gov","idp.qa.identitysandbox.gov"],"idp")).to eq false
    end
    it 'does not match nil' do
      expect(match?(["idp.*.login.gov","idp.*.identitysandbox.gov"],nil)).to eq false
    end
    it 'does not match blank' do
      expect(match?(["idp.*.login.gov","idp.*.identitysandbox.gov"],"")).to eq false
    end
    it 'does not match blank array' do
      expect(match?([],"idp.qa.login.ru")).to eq false
    end
    it 'does not match blank array to nil' do
      expect(match?([],nil)).to eq false
    end
    it 'matches two wildcards' do
      expect(match?("*.*.login.gov","idp.dev.login.gov")).to eq true
    end
    it 'does not match two wildcards' do
      expect(match?("*.*.login.gov","idp.login.gov")).to eq false
    end
  end

  def match?(pattern,str)
    WildcardPatternMatcher.match?(pattern,str)
  end
end
