require 'sinatra'

class App < Sinatra::Base
  get '/' do
    logger.info 'OK'
    'hello'
  end
end
