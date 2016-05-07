# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'black_box_log_formatter/version'

Gem::Specification.new do |spec|
  spec.name          = "black_box_log_formatter"
  spec.version       = BlackBoxLogFormatter::VERSION
  spec.authors       = ["Mike Bourgeous", "Dustin Grange", "Deseret Book"]
  spec.email         = ["webdev@deseretbook.com"]

  spec.summary       = %q{A colorful formatter and highlighter for structued log events}
  spec.description   = <<-DESC
    This is an incredibly colorful highlighting formatter for structured log
    events.  It is visually similar to Ruby's `Logger::Formatter`, but can display
    additional color-highlighted metadata on the same line or on subsequent lines.
  DESC
  spec.homepage      = "https://github.com/deseretbook/black_box_log_formatter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.1.0'

  spec.add_runtime_dependency 'awesome_print', '~> 1.6.1'

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
