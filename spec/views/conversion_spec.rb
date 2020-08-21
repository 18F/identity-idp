require 'rails_helper'
class Anything
  def initialize(token)
    @token = token
  end
  def method_missing(m, *_args)
    Anything.new(m)
  end
  def to_ary
    [to_s]
  end
  def to_s
    @token.to_s
  end
end
def remove_text_whitespace(node)
  if node.text?
    # Remove whitespace from front and back of the next
    node.content = node.content.gsub(/(\A\s+)+|(\s+\z)/, '')
    node.remove if node.content.blank?
  else
    node.children.each { |n| remove_text_whitespace(n) }
  end
end
describe 'converted slim files match' do
  slim_file_prefixes = Dir['app/views/**/*.slim'].map do |filename|
    filename.gsub(/(\.html)?\.slim/, '')
  end
  erb_file_prefixes = Dir['app/views/**/*.erb'].map do |filename|
    filename.gsub(/(\.html)?\.erb/, '')
  end
  conversion_files = slim_file_prefixes & erb_file_prefixes
  conversion_files.each do |conversion_file|
    it "converted #{conversion_file} correctly" do
      slim_filename = Dir["#{conversion_file}*.slim"].first
      html_filename = Dir["#{conversion_file}*.erb"].first
      # Set the ivars we use in the templates
      ivars = File.read(slim_filename).scan(/@(\w*)/).map(&:first)
      ivars.each do |ivar|
        assign(ivar.to_sym, Anything.new(ivar))
      end
      allow(view).to receive(:method_missing) do |m, *_args|
        Anything.new(m)
      end
      allow(view).to receive(:current_user).and_return(Anything.new('current_user'))
      html = Nokogiri::HTML(render(template: html_filename.gsub(/^app\/views\//, '')))
      slim = Nokogiri::HTML(render(template: slim_filename.gsub(/^app\/views\//, '')))
      remove_text_whitespace(html.root)
      remove_text_whitespace(slim.root)
      expect(html.canonicalize).to eq(slim.canonicalize)
    end
  end
end
