#require gems/libraries
require 'rubygems'
require 'sinatra'
require 'datamapper'
require 'json'
require 'rack-flash'
require 'net/http'
require 'open-uri'
require 'cgi'
require 'to_lang'
use Rack::Flash
ToLang.start('AIzaSyBspFjGG3EQNn3C_6ZQCDTsUEj7xHTrCMA')

#Datamapper and DataBase setup
DataMapper::Logger.new($stdout, :debug)
#sqlite3 in dev, production, Database_url is provided by hositing site
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

#db - run in memory for testing
configure :test do
  DataMapper.setup(:default, "sqlite::memory:")
end

#require application files
require 'chain_evaluator.rb'    #the scoring algorithm and score card creation object
require 'language_detector.rb'  #language detect object to prevent gaming
require 'admin_tasks.rb'        #restful tasks relating to administrator
require 'helper.rb'             #some roll my own helpers
require 'language_module.rb'    #roll my own mixin to get full language names returned for the 2 letter google codes
require 'general.rb'            #REST relating to general site http requests
require 'reg_login.rb'          #REST relating to registration and login http requests
require 'candidate.rb'          #REST relating to candidate http requests
require 'chain.rb'              #REST relating to chain http requests
require 'scorecard.rb'          #REST relating to scorecard http requests

#All the classes that follow include the Datamapper mixin, allowing them
#to be used in conjunction with the Datamapper ORM

#Candidates are the sentences used as inputs for the game
class Candidate  
  include DataMapper::Resource
  include Language #mixin - methods to return full language name
  property :id, Serial  
  property :sentence, Text, :required => true  
  property :source, Text, :required => true #source language, two letter google code  
  property :target, Text, :required => true #target language, two letter google code
  property :created_at, DateTime
  
  belongs_to :player, :required => false   #candidates can be created by players or guests
  has n, :chains
  
  #returns full source language name 
  def source_language
    lang self.source
  end
  
  #returns full target language name 
  def target_language
    lang self.target
  end  
end

#a chain is a translation chain, one of the primary objects of the game
#a candidate has many chains, meaning that many different group players
#can attempt transalting the same candidate
class Chain
  include DataMapper::Resource
  property :id, Serial
  #progress integer represents the chain's progress, 
  #0 - L2attempt dispatched 
  #1 - L2attempt submitted
  #2 - L1attempt dispatched
  #3 - L1attempt submitted - chain completed.
  property :progress, Integer, :default => 0
  property :score, Integer, :default => 0         #the score for the chain when completed 
  belongs_to :candidate
  has 1, :l1attempt
  has 1, :l2attempt
  has n, :scorecards
end
  
#first link in the chain from candidate, L2attempt should be in target language of candidate
class L2attempt
  include DataMapper::Resource
  property :sentence, Text
  property :filled, Boolean, :default => false
  property :recieved_at, EpochTime
  property :submitted_at, EpochTime
  
  belongs_to :chain, :key => true
  belongs_to :player
end

#second link in the chain after L2attempt, L1attempt is the return to the source language(i.e. same as candidate)
class L1attempt
  include DataMapper::Resource
  property :sentence, Text
  property :filled, Boolean, :default => false
  property :recieved_at, EpochTime
  property :submitted_at, EpochTime
  
  belongs_to :chain, :key => true
  belongs_to :player
end

#represents a use of the website
class Player
  include DataMapper::Resource
  property :id, Serial
  property :name, Text, :required => true, :unique => true, :length => 1..20
  property :password, Text, :required => true, :length => 6..20
  property :email, Text, :required => true, :unique => true, :format => :email_address
  property :total_score, Integer, :default => 0
  property :languages, Flag[ :en, :es, :ga, :fr ] #-like an enum but can have more than one selection
  property :joined_at, DateTime
  validates_with_method :check_lang_number #makes sure players select at least 2 languages when registering
  
  has n, :candidates
  has n, :l1attempts
  has n, :l2attempts
  has n, :scorecards
  
  def check_lang_number
    num = self.languages.size
    
    if num >= 2
      return true
    else
      [false, "You must select at least 2 languages"]
    end
  end
  
  #rank the player is at based on their current score
  def rank
    case self.total_score 
    when 0..1999
      "Slave"
    when 2000..3999
      "Labourer"
    when 4000..5999
      "Servant"
    when 6000..7999
      "Artisan"
    when 8000..9999
      "Merchant"
    when 10000..11999
      "Military Officer"
    when 12000..13999
      "Palace Official"
    when 14000..15999
      "Architect"
    when 16000..17999
      "Temple Priest"
    when 18000..19999
      "King"
    else
      "Nimrod"      #top_rank - Nimrod, leader of the Babylonians :-)
    end
  end
  
  def add_score score
    self.total_score += score
    self.save
  end
  
  #returns number chains for which a player has recieved sentences to translate but has not yet submitted
  def active_chains
    activel2s = self.l2attempts.select{|l2| l2.chain.progress == 0}
    activel1s = self.l1attempts.select{|l1| l1.chain.progress == 2}
    activel1s.size + activel2s.size
  end
  
  #predicate, returns true if player speaks the language passed
  def speaks? lang
    self.languages.include?(lang.to_sym)
  end
end

#each completed chain will have 2 scorecards, 1 for each player
class Scorecard
  include DataMapper::Resource
  property :id, Serial
  property :report, Text
  property :viewed, Boolean, :default => false
  property :created_at, DateTime
  
  belongs_to :player
  belongs_to :chain
end

#resolve changes to DB  
DataMapper.finalize.auto_upgrade!

enable :sessions

#checks to see if a player is logged in using sessions, performed on every page load
before do
  if session[:player] then @player = Player.get(session[:player]) end
end











  

  
  
  