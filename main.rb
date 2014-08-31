# encoding: utf-8

BLACKJACK = 21
DEALER_HIT_UNTIL = 17

helpers do
  def csrf_tag
    Rack::Csrf.csrf_tag(env)
  end

  def hand_value(cards)
    values = cards.map { |value| value[1] }

    total = 0
    values.each do |value|
      if value == 'A'
        total += 11
      else
        total += value.to_i == 0 ? 10 : value.to_i
      end
    end

    # correct for aces
    values.select { |value| value == 'A' }.count.times do
      break if total <= 21
      total -= 10
    end

    total
  end

  def display_card(card)
    suite = case card[0]
            when 'C' then 'clubs'
            when 'D' then 'diamonds'
            when 'H' then 'hearts'
            when 'S' then 'spades'
            end

    value = card[1]
    if %w(J Q K A).include? value
      value = case card[1]
              when 'J' then 'jack'
              when 'Q' then 'queen'
              when 'K' then 'king'
              when 'A' then 'ace'
              end
    end
    "<img src=\"/images/cards/#{suite}_#{value}.jpg\" class=\"card_image\">"
  end

  def winner!(msg)
    @show_player_buttons = false
    @show_play_again_buttons = true
    @success = "<strong>#{session[:player_name]} wins!</strong> #{msg}"
  end

  def loser!(msg)
    @show_player_buttons = false
    @show_play_again_buttons = true
    @error = "<strong>#{session[:player_name]} loses.</strong> #{msg}"
  end

  def tie!(msg)
    @show_player_buttons = false
    @show_play_again_buttons = true
    @success = "<strong>It's a tie!</strong> #{msg}"
  end
end

before do
  @show_player_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = 'Name is required.'
    halt erb(:new_player)
  end

  session[:player_name] = Rack::Utils.escape_html params[:player_name]
  redirect '/game'
end

get '/game' do
  session[:turn] = 'player'
  suites = %w(C D H S)
  values = %w(2 3 4 5 6 7 8 9 10 J Q K A)
  session[:deck] = suites.product(values).shuffle!

  session[:player_hand] = []
  session[:dealer_hand] = []

  session[:player_hand] << session[:deck].pop
  session[:dealer_hand] << session[:deck].pop
  session[:player_hand] << session[:deck].pop
  session[:dealer_hand] << session[:deck].pop

  erb :game
end

# Player actions

post '/game/player/hit' do
  session[:player_hand] << session[:deck].pop

  total = hand_value(session[:player_hand])
  if total == BLACKJACK
    winner!("#{session[:player_name]} hit blackjack.")
  elsif total > BLACKJACK
    loser!("Busted at #{total}")
  end

  erb :game
end

post '/game/player/stand' do
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = 'dealer'
  @show_player_buttons = false

  total = hand_value(session[:dealer_hand])
  if total == BLACKJACK
    loser!('Sorry. Dealer hit blackjack.')
  elsif total > BLACKJACK
    winner!('Dealer busted. You win.')
  elsif total >= DEALER_HIT_UNTIL
    # dealer stand
    redirect '/game/compare'
  else
    # dealer hit
    @show_dealer_hit_button = true
    @dealer_total = total
  end

  erb :game
end

post '/game/dealer/hit' do
  session[:dealer_hand] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_player_buttons = false
  player_total = hand_value(session[:player_hand])
  dealer_total = hand_value(session[:dealer_hand])

  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total} and the dealer stayed at #{dealer_total}")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total} and the dealer stayed at #{dealer_total}")
  else
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total}")
  end

  erb :game
end

get '/game/over' do
  erb :game_over
end
