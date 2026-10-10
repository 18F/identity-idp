require 'spec_helper'
require 'pathname'

# The project skills under .claude/skills are the source of truth; .agents/skills is a
# byte-identical twin written by .claude/skills/login-delegated-access/scripts/sync_twins.sh.
# The generated references and the document matrices are written by scripts/build_index.py
# and carry a generation header or a marker pair. Every check reads files only: no git, no
# network, no Rails.
RSpec.describe 'delegated-access skill twins and generated references' do
  let(:root) { Pathname.new(File.expand_path('../..', __dir__)) }
  let(:source) { root.join('.claude/skills') }
  let(:twin) { root.join('.agents/skills') }
  let(:skill) { source.join('login-delegated-access') }

  def relative_files(dir)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: dir.to_s)
      .reject { |path| path.end_with?('.', '..') }
      .select { |path| File.file?(dir.join(path)) }
      .sort
  end

  describe 'twins' do
    it 'has the same set of files on both sides' do
      expect(twin).to be_directory, "#{twin} is missing; run scripts/sync_twins.sh"
      expect(relative_files(twin)).to eq(relative_files(source))
    end

    it 'has byte-identical content on both sides' do
      differing = relative_files(source).reject do |path|
        twin.join(path).file? && File.binread(twin.join(path)) == File.binread(source.join(path))
      end
      expect(differing).to be_empty, "twins differ: #{differing.join(', ')}; run sync_twins.sh"
    end
  end

  describe 'generated references' do
    header = %r{
      \A<!--\ generated\ by\ \.claude/skills/login-delegated-access/scripts/build_index\.py
      \ from\ docs/\ and\ git\ at\ [0-9a-f]+;\ do\ not\ edit\ by\ hand\ -->\n
    }x

    %w[requirements-index.md traceability.md branches.md decisions.md].each do |name|
      it "#{name} exists and starts with the generation header" do
        path = skill.join('references', name)
        expect(path).to be_file, "#{path} is missing; run scripts/build_index.py"
        expect(File.read(path)).to match(header)
      end
    end
  end

  describe 'document matrices' do
    %w[
      delegated-access-implementation-plan.md
      delegated-access-functional-requirements.md
      delegated-access-requirements.md
    ].each do |name|
      it "#{name} carries exactly one generated matrix" do
        text = File.read(root.join('docs', name))
        expect(text.scan('<!-- traceability:begin -->').size).to eq(1)
        expect(text.scan('<!-- traceability:end -->').size).to eq(1)
        begin_at = text.index('<!-- traceability:begin -->')
        end_at = text.index('<!-- traceability:end -->')
        expect(begin_at).to be < end_at
      end
    end
  end

  it 'keeps SKILL.md within the 150-line limit' do
    expect(File.readlines(skill.join('SKILL.md')).size).to be <= 150
  end
end
