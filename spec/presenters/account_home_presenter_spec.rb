# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountHomePresenter do
  let(:connected_apps) { [] }
  let(:decrypted_pii) { nil }
  let(:category) { nil }
  let(:now) { Time.zone.local(2026, 7, 10, 13, 0, 0) }

  let(:connected_relation) do
    instance_double(ActiveRecord::Relation).tap do |relation|
      allow(relation).to receive(:includes).and_return(connected_apps)
      allow(relation).to receive(:any?).and_return(connected_apps.any?)
    end
  end

  let(:user) do
    instance_double(
      User,
      connected_apps: connected_relation,
      last_sign_in_email_address: instance_double(EmailAddress, email: 'user@example.com'),
    )
  end

  subject(:presenter) do
    described_class.new(user:, decrypted_pii:, now:, category:)
  end

  describe '#time_of_day_bucket / #greeting' do
    # NOTE: the bucket is derived from `now.hour`, where the controller passes
    # Time.zone.now. Greetings therefore follow the application's configured
    # time zone (Time.zone), NOT the signed-in user's local time.
    around { |example| travel_to(now) { example.run } }

    context 'in the morning' do
      let(:now) { Time.zone.local(2026, 7, 10, 8, 0, 0) }

      it 'is morning' do
        expect(presenter.time_of_day_bucket).to eq(:morning)
        expect(presenter.greeting).to eq(t('account.dashboard.greeting.morning'))
      end
    end

    context 'just before noon' do
      let(:now) { Time.zone.local(2026, 7, 10, 11, 59, 0) }

      it 'is still morning' do
        expect(presenter.time_of_day_bucket).to eq(:morning)
      end
    end

    context 'at noon' do
      let(:now) { Time.zone.local(2026, 7, 10, 12, 0, 0) }

      it 'is afternoon' do
        expect(presenter.time_of_day_bucket).to eq(:afternoon)
        expect(presenter.greeting).to eq(t('account.dashboard.greeting.afternoon'))
      end
    end

    context 'just before 6pm' do
      let(:now) { Time.zone.local(2026, 7, 10, 17, 59, 0) }

      it 'is still afternoon' do
        expect(presenter.time_of_day_bucket).to eq(:afternoon)
      end
    end

    context 'at 6pm' do
      let(:now) { Time.zone.local(2026, 7, 10, 18, 0, 0) }

      it 'is evening' do
        expect(presenter.time_of_day_bucket).to eq(:evening)
        expect(presenter.greeting).to eq(t('account.dashboard.greeting.evening'))
      end
    end

    context 'late at night' do
      let(:now) { Time.zone.local(2026, 7, 10, 23, 30, 0) }

      it 'is evening' do
        expect(presenter.time_of_day_bucket).to eq(:evening)
      end
    end
  end

  describe '#header_personalization' do
    context 'without decrypted PII' do
      it 'falls back to the last sign-in email' do
        expect(presenter.header_personalization).to eq('user@example.com')
      end
    end

    context 'with decrypted PII' do
      let(:decrypted_pii) { double('decrypted_pii', first_name: 'Jordan') }

      it 'uses the first name' do
        expect(presenter.header_personalization).to eq('Jordan')
      end
    end
  end

  describe '#selected_category' do
    context 'with no param' do
      it 'defaults to all' do
        expect(presenter.selected_category).to eq('all')
      end
    end

    context 'with a valid category' do
      let(:category) { 'travel' }

      it 'keeps it' do
        expect(presenter.selected_category).to eq('travel')
      end
    end

    context 'with an unknown / injected value' do
      let(:category) { 'not-a-category' }

      it 'falls back to all' do
        expect(presenter.selected_category).to eq('all')
      end
    end
  end

  describe '#featured_services' do
    context 'with no connected apps and no filter' do
      it 'returns the full catalog' do
        expect(presenter.featured_services.length).to eq(FeaturedService.all.length)
        expect(presenter.featured_services?).to be(true)
      end
    end

    context 'filtered by category' do
      let(:category) { 'travel' }

      it 'returns only services in that category' do
        names = presenter.featured_services.map(&:name)
        expect(names).to contain_exactly('CBP Trusted Traveler Programs', 'MyTravelGov')
      end
    end

    context 'when the user is already connected to an agency' do
      let(:connected_apps) do
        [instance_double(ServiceProviderIdentity, display_name: 'Internal Revenue Service')]
      end

      it 'excludes that agency from discovery (matched by display name)' do
        expect(presenter.featured_services.map(&:name)).not_to include('Internal Revenue Service')
      end

      it 'shows the filter chips' do
        expect(presenter.show_filters?).to be(true)
      end
    end

    context 'when a filtered category yields nothing after excluding connected apps' do
      let(:category) { 'taxes_and_money' }
      let(:connected_apps) do
        [instance_double(ServiceProviderIdentity, display_name: 'Internal Revenue Service')]
      end

      it 'reports the filtered result as empty' do
        expect(presenter.featured_services).to be_empty
        expect(presenter.featured_services?).to be(false)
      end
    end
  end

  describe '#show_filters?' do
    context 'with no connected apps' do
      it 'hides the chips (canonical empty-state frame)' do
        expect(presenter.show_filters?).to be(false)
      end
    end
  end
end
