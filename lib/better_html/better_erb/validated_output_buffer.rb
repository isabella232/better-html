module BetterHtml
  class BetterErb
    class ValidatedOutputBuffer
      def initialize(buffer)
        @output = String.new(buffer.to_s)
      end

      def safe_append=(text)
        return if text.nil?
      rescue => e
        puts "#{e.message}"
        puts "#{e.backtrace.join("\n")}"
        raise
      ensure
        @output << text unless text.nil?
      end

      def safe_attribute_value_append(context, code, auto_escape, value)
        return if value.nil?

        unless context[:attribute_quoted]
          raise DontInterpolateHere, "Do not interpolate without quotes around this "\
            "attribute value. Instead of "\
            "<#{context[:tag_name]} #{context[:attribute_name]}=#{context[:attribute_value]}<%=#{code}%>> "\
            "try <#{context[:tag_name]} #{context[:attribute_name]}=\"#{context[:attribute_value]}<%=#{code}%>\">."
        end

        @output << CGI.escapeHTML(value.to_s)
      end

      def safe_attribute_append(context, code, auto_escape, value)
        raise DontInterpolateHere, "Do not interpolate without quotes around this "\
          "attribute value. Instead of "\
          "<#{context[:tag_name]} #{context[:attribute_name]}=#{context[:attribute_value]}<%=#{code}%>> "\
          "try <#{context[:tag_name]} #{context[:attribute_name]}=\"#{context[:attribute_value]}<%=#{code}%>\">."
      end

      def safe_tag_append(context, code, auto_escape, value)
        unless value.is_a?(BetterHtml::HtmlAttributes)
          raise DontInterpolateHere, "Do not interpolate in a tag. "\
            "Instead of <#{context[:tag_name]} <%=#{code}%>> please "\
            "try <#{context[:tag_name]} <%= html_attributes(attr: value) %>>."
        end

        @output << value.to_s unless value.nil?
      end

      def safe_tag_name_append(context, code, auto_escape, value)
        return if value.nil?
        value = value.to_s

        unless value =~ /\A[a-z0-9\:\-]+\z/
          raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
            "into a tag name around: <#{context[:tag_name]}<%=#{code}%>>."
        end

        @output << value unless value.nil?
      end

      def safe_rawtext_append(context, code, auto_escape, value)
        return if value.nil?

        value = properly_escaped(value, auto_escape)

        if context[:tag_name].downcase == 'script' &&
            (value =~ /<!--/ || value =~ /<script/i || value =~ /<\/script/i)
          # https://www.w3.org/TR/html5/scripting-1.html#restrictions-for-contents-of-script-elements
          raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
            "into a script tag around: <#{context[:tag_name]}>#{context[:rawtext_text]}<%=#{code}%>."
        elsif value =~ /<#{Regexp.escape(context[:tag_name].downcase)}/i ||
            value =~ /<\/#{Regexp.escape(context[:tag_name].downcase)}/i
          raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
            "into a #{context[:tag_name].downcase} tag around: <#{context[:tag_name]}>#{context[:rawtext_text]}<%=#{code}%>."
        end

        @output << value
      end

      def safe_comment_append(context, code, auto_escape, value)
        return if value.nil?
        value = properly_escaped(value, auto_escape)

        # in a <!-- ...here --> we disallow -->
        if value =~ /-->/
          raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
            "into a html comment around: <!--#{context[:comment_text]}<%=#{code}%>."
        end

        @output << value
      end

      def safe_none_append(context, code, auto_escape, value)
        return if value.nil?
        @output << properly_escaped(value, auto_escape)
      end

      def html_safe?
        true
      end

      def html_safe
        self.class.new(@output)
      end

      def to_s
        @output.html_safe
      end

      private

      def properly_escaped(value, auto_escape)
        if value.is_a?(ValidatedOutputBuffer)
          # in html context, never escape a ValidatedOutputBuffer
          value.to_s
        else
          # in html context, follow auto_escape rule
          if auto_escape
            auto_escape_html_safe_value(value.to_s).html_safe
          else
            value.to_s
          end
        end
      end

      def auto_escape_html_safe_value(arg)
        arg.html_safe? ? arg : CGI.escapeHTML(arg)
      end
    end
  end
end
