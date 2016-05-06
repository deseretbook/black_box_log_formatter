require 'logger'
require 'digest/md5'
require 'socket'

module BlackBox
  # Colorized, structured variant of Ruby's built-in Logger::Formatter.
  class LogFormatter < ::Logger::Formatter
    # Whether to highlight log lines in color.
    attr_accessor :color

    # Initializes a color formatter for the given +logger+ (optional).  By
    # default, color will be disabled if the Logger is logging to a file
    # (uses #instance_variable_get(:@filename)), enabled based on ENV['TERM']
    # otherwise.
    #
    # If +color+ is true or false (instead of nil), then color will be
    # enabled or disabled regardless of the attached logger's target or the
    # TERM environment variable.
    def initialize(logger: nil, color: nil)
      @pidcol = nil
      @appcol = nil
      @appname = nil # App name at last time of app name color calculation
      @color = color == true || (
        color != false &&
        (!logger || !logger.instance_variable_get(:@filename)) &&
        !!(ENV['TERM'].to_s.downcase =~ /(linux|mac|xterm|ansi|putty|screen)/)
      )

      AwesomePrint.force_colors! if Kernel.const_defined?(:AwesomePrint) && @color
    end

    def call(severity, datetime, progname, msg)
      # FIXME: Add inline metadata (TID, WID, JID) even if color is disabled
      return super(severity, datetime, progname, self.class.format(msg, true, false)) unless @color

      sc = severity_color(severity)
      dc = date_color(severity)
      pc = process_color(severity)
      mc = message_color(severity)
      ac = appname_color(severity, progname)
      ec = env_color(progname)
      rc = "\e[0;1;30m"

      pid = "#{pc}##{$$}"
      host = Socket.gethostname
      env = nil
      tags = nil

      if msg.is_a?(Hash)
        t = msg[:tid]
        w = msg[:wid]
        j = msg[:jid] || msg['jid']

        pid << "#{rc}/#{digest_color_bold(t)}T-#{t}" if t
        pid << "#{rc}/#{digest_color_bold(w)}W-#{w}" if w
        pid << "#{rc}/#{digest_color_bold(j)}J-#{j}" if j

        tags = msg[:tags] if msg[:tags].is_a?(Array)
        host = msg[:host] if msg[:host].is_a?(String)
        env = msg[:env] if msg[:env]
      end

      hc = "\e[1m#{digest_color(host)}"

      "#{sc}#{severity[0..0]}#{rc}, [#{dc}#{format_datetime(datetime)}#{pc}#{pid}#{rc}] #{sc}#{severity[0..4]}" +
        "#{rc} -- #{ac}#{progname}#{env && " #{ec}(#{env})"}#{rc}: #{hc}#{host}#{rc} #{self.class.format_tags(tags)}" +
        "#{mc}#{msg2str(self.class.format(msg, false, true), mc)}\e[0m\n"
    end

    # Formats the given +event+ into a String, using AwesomePrint or
    # JSON.pretty_generate if possible, or using #inspect if not.  Removes
    # common metadata elements from Hash data, and if +add_metadata+ is
    # true, adds some of them back to the message string.
    #
    # This could definitely be cleaner.
    def self.format(event, add_metadata, ap_color)
      return event.to_s unless event.is_a?(Hash)

      event = event.clone

      msg = event.delete(:message)
      host = event.delete(:host)
      pname = event.delete(:process_name)
      env = event.delete(:env)
      pid = event.delete(:pid) # Process ID
      tid = event.delete(:tid) # Thread ID
      wid = event.delete(:wid) # Worker ID
      jid = event.delete(:jid) || event.delete('jid') # Job ID
      tags = event.delete(:tags) if event[:tags].is_a?(Array)

      event.delete(:request_id) if event[:request_id] == jid

      if add_metadata
        msg = "#{format_tags(tags)}#{msg}"
      end

      # TODO: Support highlighting of backtraces

      if event.any?
        begin
          if Kernel.const_defined?(:AwesomePrint) && event.respond_to?(:ai)
            data = event.ai(indent: -2, plain: !ap_color, multiline: true)
          else
            data = JSON.pretty_generate(event)
          end
        rescue => e
          data = event.inspect rescue "INSPECTION FAILED"
        end

        msg = "#{msg}: #{data}"
      end

      msg
    end

    # Formats an array of +tags+ as a string like "[tag1] [tag2]...", with
    # a trailing space if there are any tags.
    def self.format_tags(tags)
      "#{tags.map{|t| "[#{t}]"}.join(' ')} " if tags && tags.any?
    end

    protected
    # FIXME: These would be more efficient as constant arrays
    def severity_color(severity)
      case severity
      when 'DEBUG'
        "\e[1;30m"
      when 'INFO'
        "\e[1;34m"
      when 'WARN'
        "\e[1;33m"
      when 'ERROR'
        "\e[1;31m"
      when 'FATAL'
        "\e[1;35m"
      else
        "\e[1;36m"
      end
    end

    def message_color(severity)
      case severity
      when 'DEBUG'
        "\e[1;30m"
      when 'INFO'
        "\e[0m"
      when 'WARN'
        "\e[0;33m"
      when 'ERROR'
        "\e[0;31m"
      when 'FATAL'
        "\e[0;35m"
      else
        "\e[0;36m"
      end
    end

    def date_color(severity)
      "\e[0;36m"
    end

    def process_color(severity)
      return @pidcol if @pidcol
      @pidcol = "\e[0m#{digest_color($$)}"
    end

    def appname_color(severity, progname)
      return @appcol if @appcol && @appname == progname
      @appname = progname
      @appcol = "\e[1m#{digest_color(@appname)}"
    end

    def env_color(progname)
      return @envcol if @envcol && @appname == progname
      @appname = progname
      @envcol = "\e[0m#{digest_color(@appname)}"
    end

    # Returns a color escape based on the digest of the given +value+.
    def digest_color(value)
      "\e[#{31 + digest(value) % 6}m"
    end

    # Returns a reset, bold, and color escape based on the +value+.
    def digest_color_bold(value)
      color = digest(value) % 15 + 1
      if color > 7
        "\e[0;1;#{30 + color - 8}m"
      else
        "\e[0;#{30 + color}m"
      end
    end

    # Returns an integer based on the MD5 digest of the given +value+.
    def digest(value)
      digest = Digest::MD5.digest(value.to_s).unpack('I*')
      digest[0] ^ digest[1] ^ digest[2] ^ digest[3]
    end

    private
    # Overrides superclass to preserve the color for the message level.
    def msg2str(msg, color=nil)
      super(msg).gsub("\e[0m", "\e[0m#{color}")
    end
  end
end
