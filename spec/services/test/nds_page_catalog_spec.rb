require 'rails_helper'

RSpec.describe Test::NDSPageCatalog do
  describe '.discovered_templates' do
    subject(:discovered) { described_class.discovered_templates }

    it 'finds the known NDS branch templates' do
      expect(discovered).to include(
        'devise/sessions/new',
        'sign_up/registrations/new',
        'sign_up/passwords/new',
        'users/two_factor_authentication_setup/index',
      )
    end

    it 'includes the branchless NDS templates' do
      expect(discovered).to include(*described_class::BRANCHLESS_NDS_TEMPLATES)
    end

    it 'is not trivially empty' do
      expect(discovered.length).to be >= described_class::PAGES.length
    end

    it 'excludes partials and layouts' do
      expect(discovered).to all(satisfy { |t| !File.basename(t).start_with?('_') })
      expect(discovered).to all(satisfy { |t| !t.start_with?('layouts/') })
    end
  end

  describe '.coverage' do
    subject(:coverage) { described_class.coverage }

    it 'reports no missing NDS pages for the current tree' do
      expect(coverage[:missing]).to be_empty
    end

    it 'reports no stale catalog entries for the current tree' do
      expect(coverage[:stale]).to be_empty
    end

    it 'covers every catalog template' do
      expect(coverage[:covered]).to match_array(described_class::PAGES.map(&:template))
    end
  end

  describe '.inventory' do
    subject(:inventory) { described_class.inventory }

    it 'populates both the legacy and nds sets non-trivially' do
      expect(inventory[:legacy].length).to be >= 1
      expect(inventory[:nds].length).to be >= described_class::PAGES.length
    end

    it 'classifies a known NDS page under :nds' do
      expect(inventory[:nds].map(&:template)).to include('devise/sessions/new')
    end

    it 'classifies a known legacy page under :legacy' do
      expect(inventory[:legacy].map(&:template)).to include('account_reset/pending/show')
    end

    it 'never lists the same template in both columns' do
      expect(inventory[:nds].map(&:template) & inventory[:legacy].map(&:template)).to be_empty
    end

    it 'carries the coverage self-audit' do
      expect(inventory[:missing]).to be_empty
      expect(inventory[:stale]).to be_empty
    end
  end

  describe '.route_for_template' do
    it 'resolves a conventional GET route to a path' do
      expect(described_class.route_for_template('sign_up/registrations/new'))
        .to match(%r{/sign_up/enter_email\z})
    end

    it 'returns nil when the controller does not follow template conventions' do
      expect(described_class.route_for_template('devise/sessions/new')).to be_nil
    end
  end
end
