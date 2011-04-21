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
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/development.db")

#db run in memory for testing
configure :test do
  DataMapper.setup(:default, "sqlite::memory:")
end

#require application files
require 'chain_evaluator.rb'
require 'language_detector.rb'
require 'admin_tasks.rb'
require 'helper.rb'
require 'language_module.rb'
require 'general.rb'

#All the objects that follow include the Datamapper mixin, allowing them
#to be used in conjucntion with the Datamapper ORM
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
      "Nimrod"      #top_rank - Nimrod, leader of the Babylonians :)
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


get '/add_candidate' do    
  @title = 'Add Candidate'
  erb :add_candidate  
end

post '/add_candidate' do
  #validate the candidate sentence
  @errors = []
  if params[:sentence].empty?
    @errors << "The sentence cannot be empty"
  elsif params[:sentence].split.size < 4
    @errors << "The sentence must contain at least four words"
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
    flash[:notice] = "Your Candidate has been submitted to the tower."
    redirect '/confirmation'
  end  
end

#displays a users candidates and suggested translations
get '/display_candidates' do
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
  
  languages = []
  if params[:en_lang]
    languages << :en
  end
  
  if params[:es_lang]
    languages << :es
  end
  
  if params[:ga_lang]
    languages << :ga
  end
  
  if params[:fr_lang]
    languages << :fr
  end
  
  
  p.languages = languages
  
    
  p.joined_at = Time.now
  if p.save
    session[:player] = p.id if p 
    flash[:notice] = "Your request to join the hordes of new Babylon has been submitted to the tower"
    redirect '/confirmation'
  else
    @title = 'Registration Errors'
    @errors = p.errors
    erb :register
  end  
end

get '/login' do
  @title = 'Log in'
  erb :login
end


post '/login' do
  player = Player.first(:name => params[:name], :password => params[:password])
  
  if player
    session[:player] = player.id
    unviewed_score_cards = Scorecard.all(:player => player, :viewed => false)
    if unviewed_score_cards.size > 0
      flash[:notice] = "You have new Score Cards waiting..."
    end
    @title = "Player Control#{player.name}"
    @player = player
    erb :player_control
  else
    flash[:notice] = "That username and password combination was not recognised by the system"
    @title = "Username and password not recognised"
    erb :login
  end
end

get '/logout' do
  session[:player] = nil
  redirect '/'
end

get '/new_chain' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    if @player.active_chains >= 5
      @title = "Too many active chains"
      erb :apology
    else
      #Do not use candidates the player entered
      candidates = Candidate.all(:player.not => @player) | Candidate.all(:player => nil)
      
      #only use candidates which the player speaks both languages
      suitable_candidates = candidates.select do |can|
                              @player.speaks?(can.source) && @player.speaks?(can.target)
                            end
                                
      #Do not use candidates, on which the user previously initiated a chain
      eligible_candidates = suitable_candidates.select do |can|
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
end

post '/submit_l2' do
  chain = Chain.get(params[:chain].to_i)
  l2 = L2attempt.get(params[:chain].to_i)
  
  if l2.filled == true
    @title = "Submission already recieved"
    erb :already_recieved
  else
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
      flash[:notice] = "Your sentence was not recognised as #{chain.candidate.target_language}"
      erb :new_chain
    else  
      l2.sentence = params[:sentence]
      l2.filled = true
      l2.submitted_at = Time.now
      l2.chain.progress = 1         #stage L2 attempt filled
      l2.save
      flash[:notice] = "Your translation has been returned to the tower. You shall recieve your score card, when the chain is continued and completed by another player."
      redirect '/confirmation'
    end
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
    #the chains are at the right stage in progress, and the player speaks both target and source languages
    candidates = Candidate.all(:player.not => @player)
    chains = []
    candidates.each do |can|
      can.chains.each do |ch|
        if ch.progress == 1 && ch.l2attempt.player != @player
          if @player.speaks?(can.source) && @player.speaks?(can.target)
            chains << ch
          end
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
  
  if l1.filled == true
    @title = "Submission already recieved"
    erb :already_recieved
  else 
    sentence_inspector = LanguageDetector.new params[:sentence]
    if sentence_inspector.language != l1.chain.candidate.source
      @title = 'Complete Trans-mission'
      @l1attempt = l1
      @chain = l1.chain
      flash[:notice] = "Your sentence was not recognised as #{l1.chain.candidate.source_language}"
      erb :continue_chain
    else
      l1.sentence = params[:sentence]
      l1.filled = true
      l1.submitted_at = Time.now
      l1.chain.progress = 3         #stage L1 attempt filled
      l1.save
      session[:chain] = params[:chain].to_i
      redirect '/score_page'
    end
  end
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

get '/display_scorecards' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    @unviewed_score_cards = Scorecard.all(:player => @player, :viewed => false, :order => :created_at.desc)
    @viewed_score_cards = Scorecard.all(:player => @player, :viewed => true, :order => :created_at.desc)
    @title = "My Score Cards"
    erb :display_scorecards
  end
end

get '/scorecard/:id' do
  @score_card = Scorecard.get(params[:id])
  @title = "Score Card #{params[:id]}"
  erb :score_page
end

get '/display_chains' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    l2attempts = L2attempt.all(:player => @player)
    l1attempts = L1attempt.all(:player => @player)
    @active_l2attempts = l2attempts.select{|l2| l2.chain.progress == 0}
    @active_l1attempts = l1attempts.select{|l1| l1.chain.progress == 2}
    @title = "My active chains"
    erb :display_chains
  end
end

get '/new_chain/:id' do
  @l2attempt = L2attempt.get(params[:id])
  @candidate = @l2attempt.chain.candidate
  if @player == @l2attempt.player
    @title = "Your Trans-mission"
    erb :new_chain
  else
    @title = "Not your chain"
    erb :not_logged_in
  end
end

get '/continue_chain/:id' do
  @chain = Chain.get(params[:id])
  @l1attempt = @chain.l1attempt
  
  if @player == @l1attempt.player
    @title = 'Complete this Trans-mission'
    erb :continue_chain
  else
    @title = "Not your chain"
    erb :not_logged_in
  end
end

get '/project' do
  @title = "The Project"
  erb :project
end






  

  
  
  