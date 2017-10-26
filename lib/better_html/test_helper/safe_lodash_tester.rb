require_relative 'safety_tester_base'

module BetterHtml
  module TestHelper
    module SafeLodashTester
      include SafetyTesterBase

      SAFETY_TIPS = <<-EOF
-----------

The javascript snippets listed above do not appear to be escaped properly
in their context. Here are some tips:

Always use lodash's escape syntax inside a html tag:
  <a href="[%= value %]">
           ^^^^

Always use JSON.stringify() for html attributes which contain javascript, like 'onclick',
or twine attributes like 'data-define', 'data-context', 'data-eval', 'data-bind', etc:
  <div onclick="[%= JSON.stringify(value) %]">
                    ^^^^^^^^^^^^^^

Never use <script> tags inside lodash template.
  <script type="text/javascript">
  ^^^^^^^

-----------
EOF

      def assert_lodash_safety(data)
        tester = Tester.new(data)

        message = ""
        tester.errors.each do |error|
          message << format_safety_error(data, error)
        end

        message << SAFETY_TIPS

        assert_predicate tester.errors, :empty?, message
      end

      private

      class Tester
        attr_reader :errors

        def initialize(data)
          @data = data
          @errors = Errors.new
          @nodes = BetterHtml::NodeIterator.new(data, template_language: :lodash)
          validate!
        end

        def add_error(token, message)
          @errors.add(SafetyTesterBase::SafetyError.new(token, message))
        end

        def validate!
          @nodes.each_with_index do |node, index|
            case node
            when BetterHtml::NodeIterator::Element
              validate_element(node)

              if node.name == 'script' && !node.closing?
                add_error(node.name_parts.first,
                  "No script tags allowed nested in lodash templates")
              end
            when BetterHtml::NodeIterator::CData, BetterHtml::NodeIterator::Comment
              validate_no_statements(node)
            end
          end
        end

        def validate_element(element)
          element.attributes.each do |attribute|
            attribute.name_parts.each do |token|
              add_no_statement_error(attribute, token) if token.type == :stmt
            end

            attribute.value_parts.each do |token|
              case token.type
              when :stmt
                add_no_statement_error(attribute, token)
              when :expr_literal
                validate_tag_expression(element, attribute.name, token)
              when :expr_escaped
                add_error(token, "lodash interpolation with '[%!' inside html attribute is never safe")
              end
            end
          end
        end

        def validate_tag_expression(node, attr_name, value_token)
          if javascript_attribute_name?(attr_name) && !lodash_safe_javascript_expression?(value_token.code.strip)
            add_error(value_token, "lodash interpolation in javascript attribute "\
              "`#{attr_name}` must call `JSON.stringify(#{value_token.code.strip})`")
          end
        end

        def javascript_attribute_name?(name)
          BetterHtml.config.javascript_attribute_names.any?{ |other| other === name }
        end

        def lodash_safe_javascript_expression?(code)
          BetterHtml.config.lodash_safe_javascript_expression.any?{ |other| other === code }
        end

        def validate_no_statements(node)
          node.content_parts.each do |token|
            add_no_statement_error(node, token) if token.type == :stmt
          end
        end

        def add_no_statement_error(node, token)
          add_error(token, "javascript statement not allowed here; did you mean '[%=' ?")
        end
      end
    end
  end
end