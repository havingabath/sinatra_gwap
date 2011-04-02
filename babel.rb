require 'rubygems'
require 'sinatra'
require 'datamapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/babel.db")

#Candidates are the sentences used as inputs for the game
class Candidate  
  include DataMapper::Resource  
  property :id, Serial  
  property :sentence, Text, :required => true  
  property :source, Text, :required => true #source language, two letter google code  
  property :target, Text, :required => true #target language, two letter google code
  property :created_at, DateTime
  
  belongs_to :player, :required => false   #candidates can be created by players or guests
  has n, :chains    
end

class Chain
  include DataMapper::Resource
  property :id, Serial
  property :progress, Integer, :default => 0 #this integer represents the chains progress, 0 - nothing submitted, 1 - L2 submitted, 2 - completed
  belongs_to :candidate
  has 1, :l1attempt
  has 1, :l2attempt 
end
  

class L2attempt
  include DataMapper::Resource
  property :sentence, Text
  property :filled, Boolean, :default => false
  property :recieved_at, DateTime
  property :submitted_at, DateTime
  
  belongs_to :chain, :key => true
  belongs_to :player
end

class L1attempt
  include DataMapper::Resource
  property :sentence, Text
  property :recieved_at, DateTime
  property :submitted_at, DateTime
  
  belongs_to :chain, :key => true
  belongs_to :player
end

class Player
  include DataMapper::Resource
  property :id, Serial
  property :name, Text, :required => true
  property :password, Text, :required => true
  property :email, Text, :required => true
  property :total_score, Integer, :default => 0
  property :rank, Text, :default => 'slave'
  property :mother_tongue, Text, :required => true #mother language, two letter google code
  property :joined_at, DateTime
  
  has n, :candidates
  has n, :l1attempts
  has n, :l2attempts  
end

DataMapper.finalize.auto_upgrade!

enable :sessions

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

get '/display_all' do  
  @sentences = Candidate.all :order => :id.desc  
  @title = 'All Candidates'  
  erb :display  
end

get '/display' do
  @sentences = Candidate.all(:player => @player, :order => :created_at.desc)
  @title = "#{@player.name}'s Candidates"
  erb :display
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
  p.save
  session[:player] = p.id if p 
  redirect '/'  
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
  candidates = Candidate.all(:player.not => @player)
  @candidate = candidates[rand(candidates.size)]
  chain = Chain.create(:candidate => @candidate)
  @l2attempt = L2attempt.create(:chain => chain, :player => @player, :recieved_at => Time.now)
  chain.save
  @l2attempt.save
  @title = 'Your New Trans-mission'
  erb :new_chain
end

post '/submit_l2' do
  l2 = L2attempt.get(params[:chain].to_i)
  l2.sentence = params[:sentence]
  l2.save
  redirect '/confirmation'
end

get '/confirmation' do
  @title = 'Confirmation'
  erb :confirmation
end
  
  