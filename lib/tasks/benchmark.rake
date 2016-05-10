desc 'Crude benchmark of the log formatter'
task :benchmark do
  require 'black_box_log_formatter'
  require 'benchmark'

  benchmarks = {
    'plain string' => 'This is a message to format',
    'simple hash' => { message: 'This is a message to format' },
    'hash with data' => { message: 'This is a message to format', meta: 'data', a: 1, b: 2 },
    'hash with only data' => { meta: 'data', a: 1, b: 2 },
    'hash with backtrace' => { message: 'Something bad happened', error: caller(0, 5) },
    'hash with non-trace array' => { message: 'This is a message to format', list: (1..5).to_a },
  }

  iterations = 100000

  color = BlackBox::LogFormatter.new(color: true)
  bw = BlackBox::LogFormatter.new(color: false)

  date = Time.now.utc

  benchmarks.each do |name, message|
    puts "\n\e[1mTesting color with #{name}\e[0m"
    time = Benchmark.realtime do
      iterations.times do
        color.call('FATAL', date, 'a program', message)
      end
    end
    puts "\t#{iterations}/#{time}s = #{'%.2f' % (iterations.to_f / time)}/s"

    puts "\n\e[1mTesting non-color with #{name}\e[0m"
    time = Benchmark.realtime do
      iterations.times do
        bw.call('FATAL', date, 'a program', message)
      end
    end
    puts "\t#{iterations}/#{time}s = #{'%.2f' % (iterations.to_f / time)}/s"
  end
end
