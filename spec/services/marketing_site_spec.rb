require 'rails_helper'

RSpec.describe MarketingSite do
  shared_examples 'a marketing site URL' do
    it 'has a path which ends with a trailing slash' do
      path = URI.parse(url).path

      expect(path).to end_with('/')
    end
  end

  describe '.base_url' do
    subject(:url) { MarketingSite.base_url }

    it_behaves_like 'a marketing site URL'

    it 'points to the base URL' do
      expect(url).to eq('https://www.login.gov/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the base URL with the locale appended' do
        expect(url).to eq('https://www.login.gov/es/')
      end
    end
  end

  describe '.security_and_privacy_practices_url' do
    subject(:url) { MarketingSite.security_and_privacy_practices_url }

    it_behaves_like 'a marketing site URL'

    it 'points to the privacy page' do
      expect(url).to eq('https://www.login.gov/policy/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the privacy page with the locale appended' do
        expect(url).to eq('https://www.login.gov/es/policy/')
      end
    end
  end

  describe '.security_and_privacy_how_it_works_url' do
    subject(:url) { MarketingSite.security_and_privacy_how_it_works_url }

    it_behaves_like 'a marketing site URL'

    it 'points to the privacy page' do
      expect(url).to eq('https://www.login.gov/policy/how-does-it-work/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the privacy page with the locale appended' do
        expect(url).to eq('https://www.login.gov/es/policy/how-does-it-work/')
      end
    end
  end

  describe '.rules_of_use_url' do
    subject(:url) { MarketingSite.rules_of_use_url }

    it_behaves_like 'a marketing site URL'

    it 'points to the rules of use page' do
      expect(url).to eq('https://www.login.gov/policy/rules-of-use/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the rules of use page with the locale appended' do
        expect(url).to eq('https://www.login.gov/es/policy/rules-of-use/')
      end
    end
  end

  describe '.messaging_practices_url' do
    subject(:url) { MarketingSite.messaging_practices_url }

    it_behaves_like 'a marketing site URL'

    it 'points to messaging practices section of the privacy page' do
      expect(url).to eq('https://www.login.gov/policy/messaging-terms-and-conditions/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the privacy page section with the locale appended' do
        expect(url).to eq('https://www.login.gov/es/policy/messaging-terms-and-conditions/')
      end
    end
  end

  describe '.contact_url' do
    subject(:url) { MarketingSite.contact_url }

    it_behaves_like 'a marketing site URL'

    it 'points to the contact page' do
      expect(url).to eq('https://www.login.gov/contact/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the contact page with the locale appended' do
        expect(url).to eq('https://www.login.gov/es/contact/')
      end
    end
  end

  describe '.help_url' do
    subject(:url) { MarketingSite.help_url }

    it_behaves_like 'a marketing site URL'

    it 'points to the help page' do
      expect(url).to eq('https://www.login.gov/help/')
    end

    context 'when the user has set their locale to :es' do
      before { I18n.locale = :es }

      it 'points to the help page with the locale appended' do
        expect(url).to eq('https://www.login.gov/es/help/')
      end
    end
  end

  describe '.help_center_article_url' do
    let(:category) {}
    let(:article) {}
    let(:article_anchor) {}
    let(:url) { MarketingSite.help_center_article_url(category: category, article: article) }

    context 'with invalid article' do
      let(:category) { 'foo' }
      let(:article) { 'bar' }

      it 'raises ArgumentError' do
        expect { url }.to raise_error MarketingSite::UnknownArticleException
      end
    end

    context 'with valid article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }

      it_behaves_like 'a marketing site URL'

      it 'returns article URL' do
        expect(url).to eq(
          'https://www.login.gov/help/verify-your-identity/accepted-state-issued-identification/',
        )
      end
    end

    context 'with anchor' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }
      let(:article_anchor) { 'test-anchor-url' }
      let(:url) do
        MarketingSite.help_center_article_url(category:, article:, article_anchor:)
      end

      it_behaves_like 'a marketing site URL'

      it 'returns article URL' do
        expect(url).to eq(
          'https://www.login.gov/help/verify-your-identity/accepted-state-issued-identification/#test-anchor-url',
        )
      end
    end
  end

  describe '.valid_help_center_article?' do
    let(:category) {}
    let(:article) {}
    let(:result) { MarketingSite.valid_help_center_article?(category:, article:) }

    context 'with invalid article' do
      let(:category) { 'foo' }
      let(:article) { 'bar' }

      it { expect(result).to eq(false) }
    end

    context 'with valid article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }

      it { expect(result).to eq(true) }

      context 'with a valid anchor' do
        let(:article_anchor) { 'test-anchor-url' }
        let(:result) do
          MarketingSite.valid_help_center_article?(category:, article:, article_anchor:)
        end

        it { expect(result).to eq(true) }
      end

      context 'with an anchor that makes the URL invalid' do
        let(:article_anchor) { '<iframe>' }
        let(:result) do
          MarketingSite.valid_help_center_article?(category:, article:, article_anchor:)
        end

        it { expect(result).to eq(false) }
      end
    end
  end
end
