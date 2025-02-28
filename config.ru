require File.join(File.dirname(__FILE__), 'app.rb')
use Rack::RewindableInput::Middleware
run App