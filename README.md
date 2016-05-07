# BlackBox::LogFormatter

This is an incredibly colorful highlighting formatter for structured log
events.  It is visually similar to Ruby's `Logger::Formatter`, but can display
additional color-highlighted metadata on the same line or on subsequent lines,
using ANSI color escape sequences.

Not everyone likes this much color and detail, so you (TODO) can configure which
log event fields to display inline, which to display in a multi-line format, and
which to hide altogether.  You can also disable color.

This gem was extracted from an internal middleware framework at Deseret Book
called BlackBox Framework.  It's named for the fact that good middleware should
allow frontend services to treat backend services like a black box, not caring
about implementation details.


## Features

- Each process, thread, worker, and job gets its own color, so you can visually
  identify log messages from the same process, thread, or worker.
- Log events are colored according to severity:
  - DEBUG - dark gray
  - INFO - default
  - WARN - yellow
  - ERROR - red
  - FATAL - magenta
  - UNKNOWN - cyan
- Backtraces are colorized to make it easy to identify files, line numbers, and
  method names:

  ```ruby
  l.warn trace: caller
  ```

  ![Highlighted backtrace](screenshots/colorized_backtraces.png?raw=true)


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'black_box_log_formatter'

# Optionally add AwesomePrint for better event formatting
gem 'awesome_print'
```

## Usage

Set `BlackBox::LogFormatter` as the formatter for a logger, then pass it
`Hash`es instead of `String`s.  Event `Hash`es should be simliar to those used
by Logstash.  Do not pass untrusted data in the `message` field or as
unfiltered fields in the event.

Pass primary metadata fields using symbols as keys, not strings.

```ruby
require 'awesome_print'
require 'black_box_log_formatter'

l = Logger.new($stdout)
l.progname = 'A Program'
l.formatter = BlackBox::LogFormatter.new

l.debug "The old way to log"
# => D, [2016-05-06T16:21:44.520640 #32413] DEBUG -- A Program: hostname The old way to log

l.debug(
  message: "The new way to log",
  tid: 'some thread',
  wid: 'some worker',
  data: { useful: :fields }
)
# => D, [2016-05-06T16:22:32.027060 #32413/T-some thread/W-some worker] DEBUG -- A Program: hostname The new way to log: {
#    :data => {
#      :useful => :fields
#      }
#    }
```

![Simple logging example](screenshots/readme_example_1.png?raw=true)


TODO: describe configuring the color and formatting options


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/deseretbook/black\_box\_log\_formatter.


## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT) (see the LICENSE file).

©2016 Deseret Book and contributors.  Developed by Mike Bourgeous at
DeseretBook.com, with metadata work by Dustin Grange.  See Git for any
additional contributors.
