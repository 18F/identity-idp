module RuboCop
  module Cop
    module IdentityIdp
      class EnhancedIdvEventsLinter < RuboCop::Cop::Base
        extend AutoCorrector
        include MultilineElementLineBreaks

        RESTRICT_ON_SEND = [:track_event]

        ENHANCED_ARGS = [:proofing_components].freeze

        def on_send(track_event_send)
          method = track_event_send.each_ancestor(:def).first
          return if !should_check_method?(method.method_name)

          ENHANCED_ARGS.each do |arg_name|
            check_arg_present_on_event_method(arg_name, method)
            check_arg_present_in_track_event_send(arg_name, track_event_send)
            check_arg_has_docs(arg_name, method)
          end
        end

        private

        def check_arg_has_docs(arg_name, method)
          pattern = Regexp.new("# @param \\[.+\\] #{arg_name}")
          has_docs = preceding_lines(method).any? do |line|
            line.is_a?(Parser::Source::Comment) && pattern.match?(line.text)
          end

          return if has_docs

          add_offense(
            method,
            message: "Missing @param documentation comment for #{arg_name}",
          ) do |corrector|
            last_param_line = preceding_lines(method).reverse.find do |line|
              line.is_a?(Parser::Source::Comment) && /@param/.match?(line.text)
            end

            comment = "# @param [Object] #{arg_name} TODO: Write doc comment"
            indent = indentation_for_node(method)
            if last_param_line
              corrector.insert_after(
                last_param_line,
                "\n#{indent}#{comment}",
              )
            else
              corrector.insert_before(
                method,
                "#{comment}\n#{indent}",
              )
            end
          end
        end

        def check_arg_present_in_track_event_send(arg_name, track_event_send)
          # We expect there is a hash that includes arg_name
          hash_arg = track_event_send.each_descendant.find do |node|
            next unless node.hash_type?
            node.pairs.any? { |pair| pair.key.type == :sym && pair.key.value == arg_name }
          end

          return if hash_arg

          message = "#{arg_name} is missing from track_event call."
          add_offense(track_event_send, message:) do |corrector|
            correct_arg_missing_from_track_event_send(arg_name, track_event_send, corrector)
          end
        end

        def check_arg_present_on_event_method(arg_name, method)
          arg = method.arguments.find { |a| a.name == arg_name }
          return if arg

          add_offense(method, message: "Method is missing #{arg_name} argument.") do |corrector|
            correct_arg_missing_from_event_method(arg_name, method, corrector)
          end
        end

        def correct_arg_missing_from_event_method(arg_name, method, corrector)
          arg = method.arguments.find { |a| a.kwarg_type? && a.name == arg_name }
          return if arg

          kwrest = method.arguments.find { |a| a.kwrestarg_type? }
          return if !kwrest

          new_arg = "#{arg_name}: nil"

          if all_on_same_line?(method.arguments)
            indent = indentation_for_node(method)

            proposed_line_length = [
              indent.length,
              method.method_name.length + 2,
              method.arguments.map { |arg| arg.source }.join(', ').length,
              new_arg.length + 1,
            ].sum

            if proposed_line_length > max_line_length
              make_method_args_multiline(corrector, method)
              corrector.insert_before(kwrest, "\n#{indent}  #{new_arg},")
            else
              corrector.insert_before(kwrest, "#{new_arg}, ")
            end
          else
            indent = indentation_for_node(kwrest)
            corrector.insert_before(kwrest, "#{new_arg},\n#{indent}")
          end
        end

        def correct_arg_missing_from_track_event_send(arg_name, track_event_send, corrector)
          hash_arg = track_event_send.arguments.find { |arg| arg.hash_type? }
          return unless hash_arg

          return if hash_arg.pairs.any? { |pair| pair.key.value == arg_name }

          # Put the reference into the hash, before the splat
          kwsplat = hash_arg.children.find { |child| child.kwsplat_type? }
          return unless kwsplat

          new_arg = "#{arg_name}: #{arg_name},"
          if all_on_same_line?(track_event_send.arguments)
            indent = indentation_for_node(track_event_send)

            # We might need to convert this to a multi-line invocation
            proposed_line_length = [
              indent.length,
              track_event_send.method_name.length + 2,
              track_event_send.arguments.map { |arg| arg.source }.join(', ').length,
              new_arg.length + 1,
            ].sum

            if proposed_line_length > max_line_length
              make_send_multiline(corrector, track_event_send)
              corrector.insert_before(kwsplat, "\n#{indent}  #{new_arg}")
            else
              corrector.insert_before(kwsplat, "#{new_arg} ")
            end
          else
            # Assume that we are doing 1 arg per line
            indent = indentation_for_node(kwsplat)
            corrector.insert_before(kwsplat, "#{new_arg}\n#{indent}")
          end
        end

        def events_enhancer_class
          # Idv::AnalyticsEventsEnhancer keeps its own record of which
          # methods it wants to "enhance".

          # Force the class to be reloaded (this supports LSP-type use cases
          # where the rubocop process may be long-lived.)
          idv = begin
            Object.const_get(:Idv)
          rescue
            nil
          end

          idv&.send(:remove_const, 'AnalyticsEventsEnhancer')

          file = File.expand_path(
            '../../app/services/idv/analytics_events_enhancer.rb',
            __dir__,
          )

          load(file)

          ::Idv::AnalyticsEventsEnhancer
        end

        def make_method_args_multiline(corrector, method)
          indent = indentation_for_node(method)
          arg_indent = "\n#{indent}  "
          paren_indent = "\n#{indent}"

          method.arguments.each do |arg|
            remove_whitespace_before(arg, corrector)
            corrector.insert_before(arg, arg_indent)
          end

          corrector.insert_before(
            method.arguments.source_range.with(
              begin_pos: method.arguments.source_range.end_pos - 1,
            ),
            paren_indent,
          )
        end

        def make_send_multiline(corrector, send)
          indent = indentation_for_node(send)
          arg_indent = "\n#{indent}  "
          paren_indent = "\n#{indent}"

          send.arguments.each do |arg|
            if arg.hash_type?
              arg.children.each do |child|
                remove_whitespace_before(child, corrector)
                corrector.insert_before(child, arg_indent)
              end
            else
              remove_whitespace_before(arg, corrector)
              corrector.insert_before(arg, arg_indent)
            end
          end

          corrector.insert_before(send.loc.end, paren_indent)
        end

        def indentation_for_node(node)
          source_line = processed_source.lines[node.loc.line - 1]
          /^(?<indentation>\s*)/.match(source_line)[:indentation]
        end

        def max_line_length
          config.for_cop('Layout/LineLength')['Max'] || 100
        end

        def preceding_lines(node)
          processed_source.ast_with_comments[node].select { |line| line.loc.line < node.loc.line }
        end

        def remove_whitespace_before(node, corrector)
          char_before = node.source_range.with(
            begin_pos: node.source_range.begin_pos - 1,
            end_pos: node.source_range.begin_pos,
          )
          corrector.remove_preceding(node, 1) if /\s/.match?(char_before.source)
        end

        def should_check_method?(method_name)
          events_enhancer_class&.should_enhance_method?(method_name)
        end
      end
    end
  end
end
