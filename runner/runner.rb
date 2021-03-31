#!/usr/bin/env ruby

require 'timeout'
require 'json'

type = :code
code_installed = false
code = <<CODE
def code_runner(data)
CODE

while data = gets
  case type
  when :code then
    if data.start_with?('__END__CODE__')
      code << "end"
      type = :run
      puts "READY"
      STDOUT.flush
      #STDERR.puts code.inspect
    else
      code << data
    end
  when :run then
    if data.start_with?('EXIT')
      STDOUT.flush
      exit
    end
    run_data = JSON.parse(data, :symbolize_names => true) rescue {}
    begin
      if !code_installed
        eval(code)
        code_installed = true
      end

      result = code_runner(run_data)
      if result.is_a?(Array)
        puts result.to_json
      else
        puts [].to_json
      end
    rescue Exception => e
      puts(['error',e.message,e.backtrace].to_json)
      STDOUT.flush
      exit
    end
    STDOUT.flush
    #STDERR.puts result.inspect
  end
end
