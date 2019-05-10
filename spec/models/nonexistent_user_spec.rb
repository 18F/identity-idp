describe NonexistentUser do
  describe 'uuid' do
    it 'is set to nonexistent-uuid' do
      nonexistent_user = NonexistentUser.new

      expect(nonexistent_user.uuid).to eq 'nonexistent-uuid'
    end
  end
end
