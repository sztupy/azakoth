#\ -w -p 8080

require_relative 'server'

use Rack::Reloader, 0
use Rack::ContentLength

run App
