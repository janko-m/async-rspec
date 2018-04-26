# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'leaks'
require 'async/reactor'

module Async
	module RSpec
		module Reactor
			def run_reactor(example, duration = nil)
				result = nil
				
				duration ||= example.metadata.fetch(:timeout, 60)
				
				Async::Reactor.run do |task|
					task.annotate(self.class)
					
					reactor = task.reactor
					timer = nil
					
					if duration
						timer = reactor.async do |task|
							task.annotate("timer task duration=#{duration}")
							task.sleep(duration)
							
							buffer = StringIO.new
							reactor.print_hierarchy(buffer)
							
							reactor.stop
							
							raise TimeoutError, "run time exceeded duration #{duration}s:\r\n#{buffer.string}"
						end
					end
					
					task.async do |spec_task|
						spec_task.annotate("example runner")
						
						result = example.run
						
						if result.is_a? Exception
							reactor.stop
						else
							spec_task.children.each(&:wait)
						end
					end.wait
					
					timer.stop if timer
				end
				
				return result
			end
		end
		
		RSpec.shared_context Reactor do
			include Reactor
			
			let(:reactor) {Async::Task.current.reactor}
			
			include_context Async::RSpec::Leaks
			
			around(:each) do |example|
				run_reactor(example)
			end
		end
	end
end
