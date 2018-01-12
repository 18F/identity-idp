describe NonexistentUser do
  describe 'uuid' do
    it 'is set to nonexistent-uuid' do
      nonexistent_user = NonexistentUser.new

      expect(nonexistent_user.uuid).to eq 'nonexistent-uuid'
    end
  end

  describe 'role' do
    it 'is set to nonexistent' do
      nonexistent_user = NonexistentUser.new

      expect(nonexistent_user.role).to eq 'nonexistent'
    end
  end

  describe 'admin?' do
    it 'returns false' do
      nonexistent_user = NonexistentUser.new

      expect(nonexistent_user.admin?).to eq false
    end
  end

  describe 'tech?' do
    it 'returns false' do
      nonexistent_user = NonexistentUser.new

      expect(nonexistent_user.tech?).to eq false
    end
  end
end
