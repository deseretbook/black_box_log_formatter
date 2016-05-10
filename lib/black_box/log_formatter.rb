# Colorized, structured variant of Ruby's built-in Logger::Formatter.
# (C)2016 Deseret Book, created September 2014 by Mike Bourgeous/DeseretBook.com

require 'logger'
require 'digest/md5'
require 'socket'
require 'lru_redux'

module BlackBox
  # Colorized, structured variant of Ruby's built-in Logger::Formatter.
  class LogFormatter < ::Logger::Formatter
    COLORS = {
      severity: {
        'DEBUG' => "\e[1;30m",
        'INFO' => "\e[1;34m",
        'WARN' => "\e[1;33m",
        'ERROR' => "\e[1;31m",
        'FATAL' => "\e[1;35m",
        'ANY' => "\e[1;36m",
        nil => "\e[1;36m",
      },
      message: {
        'DEBUG' => "\e[1;30m",
        'INFO' => "\e[0m",
        'WARN' => "\e[0;33m",
        'ERROR' => "\e[0;31m",
        'FATAL' => "\e[0;35m",
        'ANY' => "\e[0;36m",
        nil => "\e[0;36m",
      },
      date: "\e[0;36m",
      process: ->(param){
        "\e[0;#{31 + digest(param) % 6}m"
      },
      progname: ->(param) {
        "\e[1;#{31 + digest(param) % 6}m"
      },
      env: ->(param){
        "\e[0;#{31 + digest(param) % 6}m"
      },
      host: ->(param){
        "\e[1;#{31 + digest(param) % 6}m"
      },
      separator: "\e[0;1;30m",

      nil => ->(param){
        color = digest(param) % 15 + 1
        if color > 7
          "\e[0;1;#{30 + color - 8}m"
        else
          "\e[0;#{30 + color}m"
        end
      },
    }

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
      @cache = LruRedux::Cache.new(50)

      @color = color == true || (
        color != false &&
        (!logger || !logger.instance_variable_get(:@filename)) &&
        !!(ENV['TERM'].to_s.downcase =~ /(linux|mac|xterm|ansi|putty|screen)/)
      )

      AwesomePrint.force_colors! if Kernel.const_defined?(:AwesomePrint) && @color
    end

    def call(severity, datetime, progname, msg)
      sc = find_color(:severity, severity)
      dc = find_color(:date)
      pc = find_color(:process, $$)
      mc = find_color(:message, severity)
      ac = find_color(:progname, progname)
      ec = find_color(:env, progname)
      rc = find_color(:separator)

      pid = "#{pc}##{$$}"
      host = Socket.gethostname
      env = nil
      tags = nil

      if msg.is_a?(Hash)
        t = msg[:tid]
        w = msg[:wid]
        j = msg[:jid] || msg['jid']

        pid << "#{rc}/#{find_color(nil, t)}T-#{t}" if t
        pid << "#{rc}/#{find_color(nil, w)}W-#{w}" if w
        pid << "#{rc}/#{find_color(nil, j)}J-#{j}" if j

        tags = msg[:tags] if msg[:tags].is_a?(Array)
        host = msg[:host] if msg[:host].is_a?(String)
        env = msg[:env] if msg[:env]
      end

      hc = find_color(:host, host)

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
    # Returns the +type+ entry from the COLORS hash if @color is true.  If the
    # entry found is a Hash, returns the +param+ entry in that Hash.  In either
    # case, if the entry isn't found in the Hash, returns the value assigned to
    # the nil key, if any.  If the final entry responds to :call, it will be
    # called with the +param+
    def find_color(type, param=nil)
      return nil unless @color

      @cache.getset([type, param]) do
        c = COLORS[type] || COLORS[nil]
        if c.is_a?(Hash)
          c = c[param] || c[nil]
        end

        c = c.call(param) if c.respond_to?(:call)

        c
      end
    end

    # Returns an integer based on the MD5 digest of the given +value+.
    def self.digest(value)
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
