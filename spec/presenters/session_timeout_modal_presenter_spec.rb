require 'rails_helper'

describe SessionTimeoutModalPresenter do
  let(:user_fully_authenticated) { nil }

  subject(:presenter) { described_class.new(user_fully_authenticated:) }

  describe '#locale_scope' do
    subject(:locale_scope) { presenter.locale_scope }

    context 'without fully authenticated user' do
      let(:user_fully_authenticated) { false }

      it 'returns the partially signed in locale scope' do
        expect(locale_scope).to eq([:notices, :timeout_warning, :partially_signed_in])
      end
    end

    context 'with fully authenticated user' do
      let(:user_fully_authenticated) { true }

      it 'returns the fully signed in locale scope' do
        expect(locale_scope).to eq([:notices, :timeout_warning, :signed_in])
      end
    end
  end
end
