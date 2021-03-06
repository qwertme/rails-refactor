require 'rubygems'
require 'spec'
require 'fileutils'

::RAILS_ROOT = File.join(File.dirname(__FILE__), 'test_app')
::RAILS_REFACTOR_ROOT = FileUtils.pwd
$LOAD_PATH << File.join(RAILS_REFACTOR_ROOT, 'lib')

require 'processor'
require 'commands/rename'
require 'support/database'
require 'support/migration_builder'

def do_with_stdout(&block)
  captured_stdout = StringIO.new
  captured_stderr = StringIO.new
  @original_stdout = $stdout
  @original_stderr = $stderr
  $stdout = captured_stdout
  $stderr = captured_stderr

  silence_warnings do
    IO.const_set('STDOUT', captured_stdout)
    IO.const_set('STDERR', captured_stderr)
  end

  begin
    yield
  ensure
    $stdout = @original_stdout
    $stderr = @original_stderr
    silence_warnings do
      IO.const_set('STDOUT', @original_stdout)
      IO.const_set('STDERR', @original_stderr)
    end
  end

  [captured_stdout.string, captured_stderr.string]
end
