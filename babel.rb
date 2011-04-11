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
DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/babel.db")

configure :test do
  DataMapper.setup(:default, "sqlite::memory:")
end

#require application files
require 'chain_evaluator.rb'
require 'language_detector.rb'
require 'deletion.rb'
require 'helper.rb'
require 'language_module.rb'

#Candidates are the sentences used as inputs for the game
class Candidate  
  include DataMapper::Resource
  include Language #mixin
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

class Chain
  include DataMapper::Resource
  property :id, Serial
  #progress integer represents the chain's progress, 
  #0 - L2attempt dispatched 
  #1 - L2attempt submitted
  #2 - L1attempt dispatched
  #3 - L2 attempt submitted - chain completed.
  property :progress, Integer, :default => 0
  property :score, Integer, :default => 0         #the score for the chain when completed 
  belongs_to :candidate
  has 1, :l1attempt
  has 1, :l2attempt
  has n, :scorecards
end
  
#first link in the chain after candidate, L2attempt should be in target language
class L2attempt
  include DataMapper::Resource
  property :sentence, Text
  property :filled, Boolean, :default => false
  property :recieved_at, DateTime
  property :submitted_at, DateTime
  
  belongs_to :chain, :key => true
  belongs_to :player
end

#second link in the chain after L2attempt, L1attempt is the return to the source language(i.e. same as candidate)
class L1attempt
  include DataMapper::Resource
  property :sentence, Text
  property :filled, Boolean, :default => false
  property :recieved_at, DateTime
  property :submitted_at, DateTime
  
  belongs_to :chain, :key => true
  belongs_to :player
end

class Player
  include DataMapper::Resource
  property :id, Serial
  property :name, Text, :required => true, :unique => true, :length => 1..20
  property :password, Text, :required => true, :length => 6..20
  property :email, Text, :required => true, :unique => true, :format => :email_address
  property :total_score, Integer, :default => 0
  property :mother_tongue, Text, :required => true #mother language, two letter google code
  property :joined_at, DateTime
  
  has n, :candidates
  has n, :l1attempts
  has n, :l2attempts
  has n, :scorecards
  
  #rank the player is at based on their current score
  def rank
    case self.total_score 
    when 0..999
      "slave"
    when 1000..1999
      "serf"
    when 2000..2999
      "architect"
    when 3000..3999
      "prince"
    when 4000..4999
      "king"
    else
      "God"
    end
  end
  
  def add_score score
    self.total_score += score
    self.save
  end 
end

class Scorecard
  include DataMapper::Resource
  property :report, Text
  property :viewed, Boolean, :default => false
  
  belongs_to :player, :key => true
  belongs_to :chain, :key => true
end
  

   

DataMapper.finalize.auto_upgrade!

enable :sessions

#checks to see if a playes is logged in using sessions
before do
  if session[:player] then @player = Player.get(session[:player]) end
end

get '/' do
  @title = 'Home'
  erb :home
end

get '/add_candidate' do    
  @title = 'Home'
  erb :add_candidate  
end

post '/add_candidate' do
  #validate the candidate sentence
  @errors = []
  if params[:sentence].empty?
    @errors << "The sentence cannot be empty"
  elsif params[:sentence].split.size < 3
    @errors << "The sentence must contain at least three words"
  end
  if params[:source] == params[:target]
    @errors << "The target language must be different from the source language"
  end
  
  #ensure source language matches google language detect
  sentence_inspect = LanguageDetector.new params[:sentence]
  if sentence_inspect.language != params[:source]
    @errors << "The sentence is not recognisable #{Language.lang(params[:source])}"
  end
  
  unless @errors.empty?
    @title = 'Candidate Errors'
    @error_sentence = params[:sentence]
    erb :add_candidate
  else
    s = Candidate.new  
    s.sentence = params[:sentence]
    s.source = params[:source]
    s.target = params[:target]  
    s.created_at = Time.now
    if @player                    #if player is logged in save it to his candidates
      @player.candidates << s
      @player.save
    else                          #if it is a guest, just save it
      s.save 
    end     
    redirect '/'
  end  
end

get'/admin_data' do
  @candidates = Candidate.all
  @chains = Chain.all
  @players = Player.all
  @title = 'Admin data'
  erb :admin_data
end

#displays a users candidates and suggested translations
get '/display' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    @candidates = Candidate.all(:player => @player, :order => :created_at.desc)
    @title = "#{@player.name}'s Candidates"
    erb :display
  end
end

get '/register' do
  @title = 'Register'
  erb :register
end

post '/register' do  
  p = Player.new  
  p.name = params[:name]
  p.email = params[:email]
  p.password = params[:password]
  p.mother_tongue = params[:mother_tongue]  
  p.joined_at = Time.now
  if p.save
    session[:player] = p.id if p 
    redirect '/'
  else
    @title = 'Registration Errors'
    @errors = p.errors
    erb :register
  end  
end

get '/leaderboard' do
  @players = Player.all :order => :total_score.desc
  @top_ten = @players.first(10)
  @title = 'Leaderboard'
  erb :leaderboard
end

get '/login' do
  @title = 'Log in'
  erb :login
end

post '/login' do
  player = Player.first(:name => params[:name], :password => params[:password])
  session[:player] = player.id if player
  redirect '/'
end

get '/new_chain' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    #Do not use candidates the player entered
    candidates = Candidate.all(:player.not => @player)
  
    #Do not use candidates, on which the user previously initiated a chain
    eligible_candidates = candidates.select do |can|
                            inclusion = true
                            can.chains.each do |ch|
                              inclusion = false if ch.l2attempt.player == @player
                            end
                            inclusion
                          end
  
    if (@candidate = eligible_candidates[rand(eligible_candidates.size)])
      chain = Chain.create(:candidate => @candidate)
      @l2attempt = L2attempt.create(:chain => chain, :player => @player, :recieved_at => Time.now)
      chain.save
      @l2attempt.save
      @title = 'Your New Trans-mission'
      erb :new_chain
    else
      @title = 'Lack of candidates in tower'
      erb :apology
    end
  end
end

post '/submit_l2' do
  chain = Chain.get(params[:chain].to_i)
  l2 = L2attempt.get(params[:chain].to_i)
  
  sentence_inspector = LanguageDetector.new params[:sentence]
  
  #if they are trying to cheat by using the same language
  if sentence_inspector.language == chain.candidate.source && sentence_inspector.confidence > 0.4 
    #penalise them and inform them of this
    @title = 'Penalty'
    @player = l2.player
    @penalty = @player.total_score / 10
    @player.total_score -= @penalty
    @player.save 
    l2.destroy
    chain.destroy
    erb :penalty
  elsif sentence_inspector.language != chain.candidate.target
    #don't penalise them but inform them the submission is unacceptable as language is not recognised target
    @title = 'Your New Trans-mission'
    @l2attempt = l2
    @candidate = chain.candidate
    flash[:notice] = "Your sentence was not recoginsed as #{chain.candidate.target_language}"
    erb :new_chain
  else  
    l2.sentence = params[:sentence]
    l2.filled = true
    l2.submitted_at = Time.now
    l2.chain.progress = 1         #stage L2 attempt filled
    l2.save
    flash[:notice] = "Your translation has been returned to the tower"
    redirect '/confirmation'
  end
end

get '/confirmation' do
  @title = 'Confirmation'
  erb :confirmation
end

get '/continue_chain' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    #find eligible chains, i.e. the logged-in player neither submitted candidate nor initiated the chain
    candidates = Candidate.all(:player.not => @player)
    chains = []
    candidates.each do |can|
      can.chains.each do |ch|
        if ch.progress == 1 && ch.l2attempt.player != @player
          chains << ch
        end
      end
    end
  
    if chains.empty?
      @title = 'Lack of chains in tower'
      erb :apology
    else
      @chain = chains[rand(chains.size)]
      @l1attempt = L1attempt.create(:chain => @chain, :player => @player, :recieved_at => Time.now)
      @chain.progress = 2         #stage L1 attempt dispatched but unfilled
      @chain.save
      @title = 'Complete this Trans-mission'
      erb :continue_chain
    end
  end
end

  

post '/submit_l1' do
  l1 = L1attempt.get(params[:chain].to_i)
  l1.sentence = params[:sentence]
  
  #TO DO - check_language -- use google language detect
  
  l1.filled = true
  l1.submitted_at = Time.now
  l1.chain.progress = 3         #stage L1 attempt filled
  l1.save
  session[:chain] = params[:chain].to_i
  redirect '/score_page'
end

get '/score_page' do
  @chain = Chain.get(session[:chain])
  scorer = ChainEvaluator.new @chain
  @score = scorer.mark
  @score_card = scorer.get_l1_scorecard
  session[:chain] = nil
  @title = 'Score Page' 
  erb :score_page
end


  
  
  