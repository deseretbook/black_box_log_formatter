# Extension for AwesomePrint that highlights Arrays of backtrace strings.  Not
# compatible with AwesomePrint's HTML output.
# (C)2016 Deseret Book, created April 2016 by Mike Bourgeous/DeseretBook.com

require 'awesome_print'

module BlackBox
  module AwesomeBacktrace
    # Regular expression identifying and modifying a backtrace line
    TRACE_REGEX = %r{(/?)([^:/]+):(\d+):in `([^']*)'}

    def self.included(base)
      base.send :alias_method, :cast_without_awesome_backtrace, :cast
      base.send :alias_method, :cast, :cast_with_awesome_backtrace
    end

    # Check for a backtrace-decorated array from BlackBox::Log.
    def cast_with_awesome_backtrace(object, type)
      if type == :array
        if defined?(::Thread::Backtrace::Location) && object.all?{|e| e.is_a?(::Thread::Backtrace::Location) }
          cast = :caller_location_backtrace
        elsif object.all?{|t| t.is_a?(String) && (t == '...' || t =~ TRACE_REGEX) }
          # FIXME: this highlights [ '...' ] as well
          cast = :string_backtrace
        end
      end

      cast || cast_without_awesome_backtrace(object, type)
    end

    # TODO: Consider using #awesome_array and formatting each string
    # separately to get the indentation and numbering for free

    # TODO: Consider searching for common backtrace filters, such as Rails,
    # for excluding unwanted backtrace entries.

    # Format a Thread::Backtrace::Location array from #caller_locations.
    def awesome_caller_location_backtrace(object)
      awesome_string_backtrace(object.map(&:to_s), '=> ', nil) # TODO: maybe use the objects directly?
    end

    # Format a String array from #caller or Exception#backtrace.
    def awesome_string_backtrace(object, open_quote='"', close_quote='"')
      open_quote = colorize(open_quote, :string) if open_quote
      close_quote = colorize(close_quote, :string) if close_quote

      s = "[\n"
      s << object.map{|s|
        s = AwesomeBacktrace.format_line(s) unless @options[:plain] || !@inspector.colorize?
        "#{indent}#{open_quote}#{s}#{close_quote},\n"
      }.join
      s << "#{outdent}]"

      s
    end

    # Adds ANSI highlights to and escapes control characters in the given
    # backtrace line.
    def self.format_line(line)
      "\e[0;36m" + line.inspect[1..-2].sub(
        TRACE_REGEX,
        "\\1\e[1;33m\\2\e[0m:\e[34m\\3\e[0m:in `\e[1;35m\\4\e[0m'"
      ).rstrip
    end
  end
end

AwesomePrint::Formatter.send(:include, BlackBox::AwesomeBacktrace)
