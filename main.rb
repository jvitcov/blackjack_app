require 'rubygems'
require 'sinatra'

# set :sessions, true
# above causes betting error in chrome

use Rack::Session::Cookie, :key => 'rack.session',
													 :path => '/',
													 :secret => 'chromebet'

BLACKJACK = 21
DEALER_MIN = 17
INITIAL_POT = 500

helpers do
	def score(cards)
		total = cards.map{ |e| e[1] }
		
		points = 0

		total.each do |card|
			if card == "A"
				points = points + 11
			elsif card.to_i == 0
				points = points + 10
			else
				points = points + card.to_i	
			end
		end

		total.select{|e| e == "A"}.count.times do
			if points > 21
				points = points - 10
			end
		end

		points
	end

	def card_img(card)
		suit = case card[0]
			when 'H' then 'hearts'
			when 'C' then 'clubs'
			when 'D' then 'diamonds'
			when 'S' then 'spades'
		end

		cards = card[1]
		if ['J', 'Q', 'K', 'A'].include?(cards)
			cards = case card[1]
				when 'J' then 'jack'
				when 'Q' then 'queen'
				when 'K' then 'king'
				when 'A' then 'ace'
			end
		end

		"<img src='/images/cards/#{suit}_#{cards}.jpg' class='card_img'>"
	end

	def winner(message)
		@play_again = true
		session[:player_pot] = session[:player_pot] + session[:player_bet]
		@success = "<strong>#{session[:player_name]} wins!</strong> #{message}"
	end

	def loser(message)
		@play_again = true
		session[:player_pot] = session[:player_pot] - session[:player_bet]
		@error = "You lost!</strong> #{message}"
	end
end

before do
	@hit_stay = true
end

get '/' do
	if session[:player_name]
		redirect '/game'
	else
  	redirect '/start'
  end
end

get '/start' do
	session[:player_pot] = INITIAL_POT
	erb :start
end

post '/player_name' do
	if params[:player_name].empty?
		@error = "You must enter your name to play."
		halt erb(:start)
	elsif params[:player_name] =~ /^[A-Za-z]+$/
		session[:player_name] = params[:player_name]
		redirect '/bet'
	else
		@error = "You must enter a valid name to play."
		halt erb(:start)
	end

	# session[:player_name] = params[:player_name]
	# redirect '/bet'
end

get '/bet' do
	session[:player_bet] = nil
	if session[:player_pot] == 0
		redirect '/no_money'
	else
		erb :bet
	end
end

get '/no_money' do
	erb :no_money
end

post '/bet' do
	if params[:player_bet].nil? || params[:player_bet].to_i == 0
		@error = "You must make a bet."
		halt erb(:bet)
	elsif params[:player_bet].to_i < 0
		@error = "You cannot bet a negative amount."
		halt erb(:bet)
	elsif params[:player_bet].to_i > session[:player_pot]
		@error = "You cannot bet more that what you have."
		halt erb(:bet)
	else
		session[:player_bet] = params[:player_bet].to_i
		redirect '/game'
	end	
end

get '/game' do
	session[:turn] = session[:player_name]
	#set up initial game values:
	suit = ['H', 'D', 'C', 'S']
	cards = ['2', '3', '4', '5', '6', '7', '8', '9', 'J', 'Q', 'K', 'A']
	session[:deck] = suit.product(cards).shuffle!
	# deal cards
	session[:dealer_cards] = []
	session[:player_cards] = []
	session[:dealer_cards] << session[:deck].pop
	session[:player_cards] << session[:deck].pop
	session[:dealer_cards] << session[:deck].pop
	session[:player_cards] << session[:deck].pop
	player_total = score(session[:player_cards])
	if player_total == BLACKJACK
		@hit_stay = false
		session[:turn] = "dealer"
		winner("Blackjack! You win!")
		erb :game
	else
		erb :game
	end
end

post '/game/player/hit' do
	session[:player_cards] << session[:deck].pop

	player_total = score(session[:player_cards])
	if player_total == BLACKJACK
		@hit_stay = false
		session[:turn] = "dealer"
		winner("Blackjack!")
	elsif player_total > BLACKJACK
		session[:turn] = "dealer"
		@hit_stay = false
		loser("With #{player_total}, you busted. Dealer wins.")
	end
	erb :game, layout: false 
end

post '/game/player/stay' do
	
	@hit_stay = false
	redirect '/game/dealer'
end

get '/game/dealer' do
	session[:turn] = 'dealer'
	dealer_total = score(session[:dealer_cards])
	player_total = score(session[:player_cards])
	if player_total > dealer_total
		@success = "You choose to stay with #{player_total}. </br> Dealer's turn..."
	end
	@hit_stay = false
	if dealer_total == BLACKJACK
		loser("Dealer hit blackjack! Sorry #{session[:player_name]}, dealer won.")
	elsif dealer_total > BLACKJACK
		winner("Dealer busted. You win!")
	elsif dealer_total >= DEALER_MIN
		#dealer stays, determine winner
		redirect 'game/compare'
	else #dealer total is less than 17
		#dealer turn
		@dealer_hit = true
	end
	erb :game, layout: false
end

post '/game/dealer/hit' do
	session[:dealer_cards] << session[:deck].pop
	redirect '/game/dealer'
end

get '/game/compare' do
	@hit_stay = false
	player_total = score(session[:player_cards])
	dealer_total = score(session[:dealer_cards])
	if dealer_total > BLACKJACK
		winner("Dealer busted. You win!")
	elsif player_total < dealer_total
		loser("You stayed at #{player_total}, while the dealer stayed with #{dealer_total}.")
	elsif player_total > dealer_total
		winner("You stayed at #{player_total}, while the dealer stayed with #{dealer_total}.")
	else #tie
		loser("You both stayed at #{player_total}. Dealer wins when tied.")
	end
	erb :game, layout: false
end

get '/game_over' do
	erb :game_over
end