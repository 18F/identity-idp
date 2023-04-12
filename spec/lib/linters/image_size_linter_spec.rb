require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../lib/linters/image_size_linter'

describe RuboCop::Cop::IdentityIdp::ImageSizeLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::ImageSizeLinter.new(config) }

  it 'registers offense when calling image_tag without any size attributes' do
    expect_offense(<<~RUBY)
      image_tag 'example.svg'
      ^^^^^^^^^^^^^^^^^^^^^^^ Assign width and height to images
    RUBY
  end

  it 'registers offense when calling image_tag with only one of width or height' do
    expect_offense(<<~RUBY)
      image_tag 'example.svg', width: 10
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Assign width and height to images
    RUBY
  end

  it 'registers no offense if there is ambiguous hash splatting' do
    expect_no_offenses(<<~RUBY)
      image_tag 'example.svg', **size_attributes
    RUBY
  end

  it 'registers no offense when calling image_tag with size' do
    expect_no_offenses(<<~RUBY)
      image_tag 'example.svg', size: 10
    RUBY
  end

  it 'registers no offense when calling image_tag with width and height' do
    expect_no_offenses(<<~RUBY)
      image_tag 'example.svg', width: 10, height: 20
    RUBY
  end
end
