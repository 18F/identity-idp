require 'rails_helper'

describe Idv::Attempter do
  let(:current_user) { User.new }
  let(:subject) { Idv::Attempter.new(current_user) }

  describe '#window_expired?' do
    context 'inside window' do
      before do
        current_user.idv_attempted_at = Time.zone.now
      end

      it 'returns false' do
        expect(subject.window_expired?).to eq false
      end
    end

    context 'outside window' do
      before do
        current_user.idv_attempted_at = Time.zone.now - 25.hours
      end

      it 'returns true' do
        expect(subject.window_expired?).to eq true
      end
    end
  end

  describe '#exceeded?' do
    context 'no attempts yet made' do
      context 'inside the window' do
        before do
          current_user.idv_attempted_at = Time.zone.now
        end

        it 'returns false' do
          expect(subject.exceeded?).to eq false
        end
      end

      context 'outside the window' do
        before do
          current_user.idv_attempted_at = Time.zone.now - 25.hours
        end

        it 'returns false' do
          expect(subject.exceeded?).to eq false
        end
      end
    end

    context 'max attempts exceeded' do
      before do
        current_user.idv_attempts = 3
      end

      context 'inside the window' do
        before do
          current_user.idv_attempted_at = Time.zone.now
        end

        it 'returns true' do
          expect(subject.exceeded?).to eq true
        end
      end

      context 'outside the window' do
        before do
          current_user.idv_attempted_at = Time.zone.now - 25.hours
        end

        it 'returns false' do
          expect(subject.exceeded?).to eq false
        end
      end
    end
  end
end
