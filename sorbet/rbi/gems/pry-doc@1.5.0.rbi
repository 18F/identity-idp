# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `pry-doc` gem.
# Please instead update this file by running `bin/tapioca gem pry-doc`.


# source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#3
class Pry
  extend ::Forwardable

  # source://pry/0.14.2/lib/pry/pry_instance.rb#81
  def initialize(options = T.unsafe(nil)); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#212
  def add_sticky_local(name, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#35
  def backtrace; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#35
  def backtrace=(_arg0); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#32
  def binding_stack; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#32
  def binding_stack=(_arg0); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def color(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def color=(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def commands(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def commands=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#145
  def complete(str); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#50
  def config; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#124
  def current_binding; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#124
  def current_context; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#33
  def custom_completions; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#33
  def custom_completions=(_arg0); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def editor(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def editor=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#255
  def eval(line, options = T.unsafe(nil)); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#34
  def eval_string; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#34
  def eval_string=(_arg0); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#286
  def evaluate_ruby(code); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def exception_handler(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def exception_handler=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#394
  def exec_hook(name, *args, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#42
  def exit_value; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def extra_sticky_locals(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def extra_sticky_locals=(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def hooks(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def hooks=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#173
  def inject_local(name, value, binding); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#201
  def inject_sticky_locals!; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def input(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def input=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#45
  def input_ring; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#39
  def last_dir; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#39
  def last_dir=(_arg0); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#41
  def last_exception; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#418
  def last_exception=(exception); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#38
  def last_file; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#38
  def last_file=(_arg0); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#37
  def last_result; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#37
  def last_result=(_arg0); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#440
  def last_result_is_exception?; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#190
  def memory_size; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#195
  def memory_size=(size); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#538
  def output; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def output=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#48
  def output_ring; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#530
  def pager; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def pager=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#522
  def pop_prompt; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def print(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def print=(*args, **_arg1, &block); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#325
  def process_command(val); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#360
  def process_command_safely(val); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#101
  def prompt; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#108
  def prompt=(new_prompt); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#131
  def push_binding(object); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#118
  def push_initial_binding(target = T.unsafe(nil)); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#506
  def push_prompt(new_prompt); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#592
  def quiet?; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#582
  def raise_up(*args); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#586
  def raise_up!(*args); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#554
  def raise_up_common(force, *args); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#282
  def repl(target = T.unsafe(nil)); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#231
  def reset_eval_string; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#375
  def run_command(val); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#453
  def select_prompt; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#409
  def set_last_result(result, code = T.unsafe(nil)); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#447
  def should_print?; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#298
  def show_result(result); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#216
  def sticky_locals; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#36
  def suppress_output; end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#36
  def suppress_output=(_arg0); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#428
  def update_input_history(code); end

  private

  # source://pry/0.14.2/lib/pry/pry_instance.rb#680
  def ensure_correct_encoding!(val); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#688
  def generate_prompt(prompt_proc, conf); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#598
  def handle_line(line, options); end

  # source://pry/0.14.2/lib/pry/pry_instance.rb#697
  def prompt_stack; end

  class << self
    # source://pry/0.14.2/lib/pry/code.rb#12
    def Code(obj); end

    # source://pry/0.14.2/lib/pry/method.rb#9
    def Method(obj); end

    # source://pry/0.14.2/lib/pry/wrapped_module.rb#7
    def WrappedModule(obj); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#294
    def auto_resize!; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#347
    def binding_for(target); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#22
    def cli; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#22
    def cli=(_arg0); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def color(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def color=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def commands(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def commands=(*args, **_arg1, &block); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#25
    def config; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#25
    def config=(_arg0); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#46
    def configure; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#380
    def critical_section; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#63
    def current; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#19
    def current_line; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#19
    def current_line=(_arg0); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#18
    def custom_completions; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#18
    def custom_completions=(_arg0); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def editor(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def editor=(*args, **_arg1, &block); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#21
    def eval_path; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#21
    def eval_path=(_arg0); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def exception_handler(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def exception_handler=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def extra_sticky_locals(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def extra_sticky_locals=(*args, **_arg1, &block); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#139
    def final_session_setup; end

    # source://forwardable/1.3.3/forwardable.rb#231
    def history(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def history=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def hooks(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def hooks=(*args, **_arg1, &block); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#375
    def in_critical_section?; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#338
    def init; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#257
    def initial_session?; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#129
    def initial_session_setup; end

    # source://forwardable/1.3.3/forwardable.rb#231
    def input(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def input=(*args, **_arg1, &block); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#24
    def last_internal_error; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#24
    def last_internal_error=(_arg0); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#20
    def line_buffer; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#20
    def line_buffer=(_arg0); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#69
    def load_file_at_toplevel(file); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#202
    def load_file_through_repl(file_name); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#251
    def load_history; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#77
    def load_rc_files; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#101
    def load_requires; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#109
    def load_traps; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#113
    def load_win32console; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#55
    def main; end

    # source://forwardable/1.3.3/forwardable.rb#231
    def memory_size(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def memory_size=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def output(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def output=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def pager(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def pager=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def print(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def print=(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def prompt(*args, **_arg1, &block); end

    # source://forwardable/1.3.3/forwardable.rb#231
    def prompt=(*args, **_arg1, &block); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#23
    def quiet; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#23
    def quiet=(_arg0); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#86
    def rc_files_to_load; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#94
    def real_path_to(file); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#326
    def reset_defaults; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#277
    def run_command(command_string, options = T.unsafe(nil)); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#156
    def start(target = T.unsafe(nil), options = T.unsafe(nil)); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#354
    def toplevel_binding; end

    # source://pry/0.14.2/lib/pry/pry_class.rb#372
    def toplevel_binding=(_arg0); end

    # source://pry/0.14.2/lib/pry/pry_class.rb#225
    def view_clip(obj, options = T.unsafe(nil)); end

    private

    # source://pry/0.14.2/lib/pry/pry_class.rb#388
    def mutex_available?; end
  end
end

# First line is the name of the file
# Following lines are the symbols followed by line number with char 127 as separator.
#
# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#1
module Pry::CInternals; end

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#7
class Pry::CInternals::CodeFetcher
  include ::Pry::Helpers::Text

  # @return [CodeFetcher] a new instance of CodeFetcher
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#32
  def initialize(line_number_style: T.unsafe(nil)); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#37
  def fetch_all_definitions(symbol); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#49
  def fetch_first_definition(symbol, index = T.unsafe(nil)); end

  # Returns the value of attribute line_number_style.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#29
  def line_number_style; end

  # Returns the value of attribute symbol_extractor.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#30
  def symbol_extractor; end

  private

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#73
  def start_line_for(line); end

  # @return [Boolean]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#69
  def use_line_numbers?; end

  class << self
    # Returns the value of attribute ruby_source_folder.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#11
    def ruby_source_folder; end

    # Sets the attribute ruby_source_folder
    #
    # @param value the value to set the attribute ruby_source_folder to.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#11
    def ruby_source_folder=(_arg0); end

    # Returns the value of attribute ruby_source_installer.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#12
    def ruby_source_installer; end

    # Sets the attribute ruby_source_installer
    #
    # @param value the value to set the attribute ruby_source_installer to.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#12
    def ruby_source_installer=(_arg0); end

    # The Ruby version that corresponds to a downloadable release
    # Note that after Ruby 2.1.0 they exclude the patchlevel from the release name
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#18
    def ruby_version; end

    # Returns a hash that maps C symbols to an array of SourceLocations
    # e.g: symbol_map["VALUE"] #=> [SourceLocation_1, SourceLocation_2]
    # A SourceLocation is defined like this: Struct.new(:file, :line, :symbol_type)
    # e.g file: "foo.c", line: 20, symbol_type: "function"
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#81
    def symbol_map; end

    # Sets the attribute symbol_map
    #
    # @param value the value to set the attribute symbol_map to.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/code_fetcher.rb#13
    def symbol_map=(_arg0); end
  end
end

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#11
class Pry::CInternals::ETagParser
  # @return [ETagParser] a new instance of ETagParser
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#14
  def initialize(tags_path, ruby_source_folder); end

  # Returns the value of attribute ruby_source_folder.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#8
  def ruby_source_folder; end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#19
  def symbol_map; end

  # Returns the value of attribute tags_path.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#7
  def tags_path; end

  private

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#54
  def clean_file_name(file_name); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#45
  def file_name_and_content_for(c_file_section); end

  # \f\n  indicates a new C file boundary in the etags file.
  # The first line is the name of the C file, e.g foo.c
  # The successive lines contain information about the symbols for that file.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#35
  def parse_tagfile; end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#50
  def tagfile; end

  class << self
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#10
    def symbol_map_for(tags_path, ruby_source_folder); end
  end
end

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#12
class Pry::CInternals::ETagParser::CFile
  # @return [CFile] a new instance of CFile
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#20
  def initialize(file_name: T.unsafe(nil), content: T.unsafe(nil), ruby_source_folder: T.unsafe(nil)); end

  # Returns the value of attribute file_name.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#17
  def file_name; end

  # Sets the attribute file_name
  #
  # @param value the value to set the attribute file_name to.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#17
  def file_name=(_arg0); end

  # Returns the value of attribute ruby_source_folder.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#18
  def ruby_source_folder; end

  # Convert a C file to a map of symbols => SourceLocation that are found in that file
  # e.g
  # { "foo" => [SourceLocation], "bar"  => [SourceLocation] }
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#29
  def symbol_map; end

  private

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#86
  def cleanup_linenumber(line_number); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#81
  def cleanup_symbol(symbol); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#46
  def full_path_for(file_name); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#41
  def source_location_for(symbol, line_number); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#63
  def symbol_type_for(symbol); end

  # @return [Boolean]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#55
  def windows?; end
end

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#15
Pry::CInternals::ETagParser::CFile::ALTERNATIVE_SEPARATOR = T.let(T.unsafe(nil), String)

# Used to separate symbol from line number
#
# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/c_file.rb#14
Pry::CInternals::ETagParser::CFile::SYMBOL_SEPARATOR = T.let(T.unsafe(nil), String)

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/etag_parser.rb#5
class Pry::CInternals::ETagParser::SourceLocation < ::Struct
  # Returns the value of attribute file
  #
  # @return [Object] the current value of file
  def file; end

  # Sets the attribute file
  #
  # @param value [Object] the value to set the attribute file to.
  # @return [Object] the newly set value
  def file=(_); end

  # Returns the value of attribute line
  #
  # @return [Object] the current value of line
  def line; end

  # Sets the attribute line
  #
  # @param value [Object] the value to set the attribute line to.
  # @return [Object] the newly set value
  def line=(_); end

  # Returns the value of attribute symbol_type
  #
  # @return [Object] the current value of symbol_type
  def symbol_type; end

  # Sets the attribute symbol_type
  #
  # @param value [Object] the value to set the attribute symbol_type to.
  # @return [Object] the newly set value
  def symbol_type=(_); end

  class << self
    def [](*_arg0); end
    def inspect; end
    def keyword_init?; end
    def members; end
    def new(*_arg0); end
  end
end

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#2
class Pry::CInternals::RubySourceInstaller
  # @return [RubySourceInstaller] a new instance of RubySourceInstaller
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#10
  def initialize(ruby_version, ruby_source_folder); end

  # Returns the value of attribute curl_cmd.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#6
  def curl_cmd; end

  # Sets the attribute curl_cmd
  #
  # @param value the value to set the attribute curl_cmd to.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#6
  def curl_cmd=(_arg0); end

  # Returns the value of attribute etag_binary.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#7
  def etag_binary; end

  # Sets the attribute etag_binary
  #
  # @param value the value to set the attribute etag_binary to.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#7
  def etag_binary=(_arg0); end

  # Returns the value of attribute etag_cmd.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#8
  def etag_cmd; end

  # Sets the attribute etag_cmd
  #
  # @param value the value to set the attribute etag_cmd to.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#8
  def etag_cmd=(_arg0); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#17
  def install; end

  # Returns the value of attribute ruby_source_folder.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#4
  def ruby_source_folder; end

  # Returns the value of attribute ruby_version.
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#3
  def ruby_version; end

  private

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#80
  def arch; end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#56
  def ask_for_install; end

  # @param message [String] Message to display on error
  # @param block [&Block] Optional assertion
  # @raise [Pry::CommandError]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#76
  def check_for_error(message, &block); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#66
  def download_ruby; end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#84
  def generate_tagfile; end

  # @return [Boolean]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#48
  def linux?; end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#27
  def set_platform_specific_commands; end

  # @return [Boolean]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/ruby_source_installer.rb#40
  def windows?; end
end

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals.rb#4
class Pry::CInternals::ShowSourceWithCInternals < ::Pry::Command::ShowSource
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals.rb#5
  def options(opt); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals.rb#26
  def process; end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals.rb#10
  def show_c_source; end

  private

  # We can number lines with their actual line numbers
  # or starting with 1 (base-one)
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals.rb#42
  def line_number_style; end
end

# source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#2
class Pry::CInternals::SymbolExtractor
  # @return [SymbolExtractor] a new instance of SymbolExtractor
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#8
  def initialize(ruby_source_folder); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#12
  def extract(info); end

  private

  # @return [Boolean]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#97
  def balanced?(str); end

  # @return [Boolean]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#89
  def complete_function_signature?(str); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#77
  def extract_code(info, offset: T.unsafe(nil), start_line: T.unsafe(nil), direction: T.unsafe(nil), &block); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#55
  def extract_function(info); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#32
  def extract_macro(info); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#50
  def extract_oneliner(info); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#38
  def extract_struct(info); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#44
  def extract_typedef_struct(info); end

  # @return [Boolean]
  #
  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#93
  def function_return_type?(str); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#106
  def source_from_file(file); end

  # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#102
  def token_count(tokens, token); end

  class << self
    # Returns the value of attribute file_cache.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#4
    def file_cache; end

    # Sets the attribute file_cache
    #
    # @param value the value to set the attribute file_cache to.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/show_source_with_c_internals/symbol_extractor.rb#4
    def file_cache=(_arg0); end
  end
end

# source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#4
module Pry::MethodInfo
  class << self
    # Retrieves aliases of the given method.
    #
    # @param meth [Method, UnboundMethod] The method object
    # @return [Array<UnboundMethod>] the aliases of the given method if they
    #   exist, otherwise an empty array
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#56
    def aliases(meth); end

    # FIXME: this is unnecessarily limited to ext/ and lib/ directories.
    #
    # @return [String] the root directory of a given gem directory
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#73
    def gem_root(dir); end

    # Retrieve the YARD object that contains the method data.
    #
    # @param meth [Method, UnboundMethod] The method object
    # @return [YARD::CodeObjects::MethodObject] the YARD data for the method
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#45
    def info_for(meth); end

    private

    # Caches the file that holds the method.
    #
    # Cannot cache C stdlib and eval methods.
    #
    # @param meth [Method, UnboundMethod] The method object.
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#205
    def cache(meth); end

    # @param meth [Method, UnboundMethod] The method object
    # @return [String, nil] root directory path of gem that method belongs to
    #   or nil if could not be found
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#145
    def find_gem_dir(meth); end

    # Try to recover the gem directory of a gem based on a method object.
    #
    # @param meth [Method, UnboundMethod] The method object
    # @return [String, nil] the located gem directory
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#188
    def gem_dir_from_method(meth); end

    # Try to guess what the gem name will be based on the name of the module.
    #
    # @param name [String] The name of the module
    # @return [Enumerator] the enumerator which enumerates on possible names
    #   we try to guess
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#171
    def guess_gem_name(name); end

    # Checks whether `meth` is a class method.
    #
    # @param meth [Method, UnboundMethod] The method to check
    # @return [Boolean] true if singleton, otherwise false
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#101
    def is_singleton?(meth); end

    # @return [Object] the host of the method (receiver or owner)
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#137
    def method_host(meth); end

    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#226
    def namespace_name(host); end

    # Attempts to find the C source files if method belongs to a gem and use
    # YARD to parse and cache the source files for display.
    #
    # @param meth [Method, UnboundMethod] The method object
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#125
    def parse_and_cache_if_gem_cext(meth); end

    # Convert a method object into the `Class#method` string notation.
    #
    # @note This mess is needed to support all the modern Rubies. Somebody has
    #   to figure out a better way to distinguish between class methods and
    #   instance methods.
    # @param meth [Method, UnboundMethod]
    # @return [String] the method in string receiver notation
    #
    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#88
    def receiver_notation_for(meth); end

    # source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#105
    def registry_lookup(meth); end
  end
end

# @return [Regexp] a pattern that matches `method_instance.inspect`
#
# source://pry-doc//lib/pry-doc/pry_ext/method_info.rb#6
Pry::MethodInfo::METHOD_INSPECT_PATTERN = T.let(T.unsafe(nil), Regexp)

# source://pry-doc//lib/pry-doc.rb#1
module PryDoc
  class << self
    # source://pry-doc//lib/pry-doc.rb#2
    def load_yardoc(version); end

    # source://pry-doc//lib/pry-doc.rb#14
    def root; end
  end
end

# source://pry-doc//lib/pry-doc/version.rb#2
PryDoc::VERSION = T.let(T.unsafe(nil), String)