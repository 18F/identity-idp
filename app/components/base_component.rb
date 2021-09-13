require 'erb'

class BaseComponent
  include ActiveModel::Validations

  def render_in(view_context, &block)
    self.class.compile
    @view_context = view_context
    @block = block if block
    validate!
    rendered_template
  end

  def self.compile
    return if @compiled
    compiler = ERB::Compiler.new('<>')
    compiler.pre_cmd = ['_erbout=+""']
    compiler.put_cmd = '_erbout.<<'
    compiler.insert_cmd = '_erbout.<<'
    compiler.post_cmd = ['_erbout.respond_to?(:html_safe) ? _erbout.html_safe : _erbout']
    code, = compiler.compile(File.read(File.join(File.dirname(__FILE__), template_file)))
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def rendered_template
        #{code}
      end
    RUBY
    @compiled = true
  end

  def self.template_file
    self.name.gsub(/(.)([A-Z])/, '\\1_\\2').downcase.ext('.html.erb')
  end

  private

  def content
    return unless @block
    if @view_context.respond_to?(:capture)
      @view_context.capture(&@block)
    else
      @block.call
    end
  end
end
