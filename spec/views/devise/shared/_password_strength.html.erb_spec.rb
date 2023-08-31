require 'rails_helper'

RSpec.describe 'devise/shared/_password_strength.html.erb' do
  describe 'forbidden attributes' do
    context 'when local is unassigned' do
      before do
        render
      end

      it 'omits data-forbidden attribute from strength text tag' do
        expect(rendered).to have_selector('#pw-strength-txt:not([data-forbidden])')
      end
    end

    context 'when local is nil' do
      before do
        render 'devise/shared/password_strength', forbidden_passwords: nil
      end

      it 'omits data-forbidden attribute from strength text tag' do
        expect(rendered).to have_selector('#pw-strength-txt:not([data-forbidden])')
      end
    end

    context 'when local is assigned' do
      before do
        render 'devise/shared/password_strength', forbidden_passwords: ['a', 'b', 'c']
      end

      it 'adds JSON-encoded data-forbidden to strength text tag' do
        expect(rendered).to have_selector('#pw-strength-txt[data-forbidden="[\"a\",\"b\",\"c\"]"]')
      end
    end
  end
end
