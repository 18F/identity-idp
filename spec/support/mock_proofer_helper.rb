def expect_mock_proofer_matches_real_proofer(mock_proofer_class:, real_proofer_class:)
  describe '.required_attributes' do
    it 'has the same required_attributes as the real proofer' do
      expect(mock_proofer_class.required_attributes).
        to match_array(real_proofer_class.required_attributes)
    end
  end

  describe '.optional_attributes' do
    it 'has the same optional_attributes as the real proofer' do
      expect(mock_proofer_class.optional_attributes).
        to match_array(real_proofer_class.optional_attributes)
    end
  end

  describe '.stage' do
    it 'has the same stage as the real proofer' do
      expect(mock_proofer_class.stage).to eq(real_proofer_class.stage)
    end
  end
end
