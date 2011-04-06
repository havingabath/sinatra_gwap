require 'rubygems'
require 'json'
require 'net/http'
require 'open-uri'
require 'cgi'

class LanguageDetector
  attr_reader :language, :confidence
  
  def initialize sentence
    @sentence = sentence
    base_url = 'http://www.google.com/uds/GlangDetect?v=1.0&q='
    key = '&key=AIzaSyBspFjGG3EQNn3C_6ZQCDTsUEj7xHTrCMA'
    url = base_url + CGI.escape(@sentence) + key
    response = Net::HTTP.get_response(URI.parse(url))
    result = JSON.parse(response.body)
    @language = result['responseData']['language']
    @confidence = result['responseData']['confidence']
    @is_reliable = result['responseData']['isReliable']
  end
  
  def is_reliable?
    @is_relaible
  end
end
  
  
    