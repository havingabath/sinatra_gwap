#general website REST

get '/' do
  @title = 'Home'
  erb :home
end

get '/about' do
  @title = 'The Tower of Babel: How to play'
  erb :about
end

get '/leaderboard' do
  @players = Player.all :order => :total_score.desc
  @top_ten = @players.first(10)
  @title = 'Leaderboard'
  erb :leaderboard
end

get '/confirmation' do
  @title = 'Confirmation'
  erb :confirmation
end

get '/project' do
  @title = "The Project"
  erb :project
end