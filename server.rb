#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'eventmachine'
require 'websocket-eventmachine-server'
require 'json'

$sockets = []

SIZE = 25
PLAYERS = 3
ROBOTS = 20
COINS = 20
MAX_VALUE = 5

LEVEL = ENV['LEVEL'].to_i

case LEVEL
when 2 then
  WALLS = false
  STEALING = false
  TICK_LENGTH = 0.5
  TIME = 15*60
when 3 then
  WALLS = true
  STEALING = false
  TICK_LENGTH = 0.25
  TIME = 10*60
when 4 then
  WALLS = true
  STEALING = true
  TICK_LENGTH = 0.1
  TIME = 5*60
else
  WALLS = false
  STEALING = false
  TICK_LENGTH = 1
  TIME = 20*60
end

PLAYER_CODES = [
  '951ab5f4-407d-4fd9-97f6-5dea67dfdbd3',
  '44ec23a9-7d94-446a-a5a8-d1e52ea07c4e',
  '4fb0d789-1b05-40cd-9c8c-046444cfc4d4'
]

class Map
  def initialize
    @hq = [[0,0], [SIZE-1,SIZE-1], [0,SIZE-1]]
    @players = []
    @players_internal = []
    @coins = []
    @score = [0, 0, 0]
    @walls = []
    @error_log = []
    @start_time = Time.new

    if WALLS
      (0...5).each do |i|
        @walls << [8,i]
        @walls << [i,8]

        @walls << [8,SIZE-i-1]
        @walls << [SIZE-i-1,8]

        @walls << [SIZE-9,i]
        @walls << [i,SIZE-9]

        @walls << [SIZE-9,SIZE-i-1]
        @walls << [SIZE-i-1,SIZE-9]
      end

      ((SIZE/2-2)...(SIZE/2+3)).each do |x|
        ((SIZE/2-2)...(SIZE/2+3)).each do |y|
          @walls << [x,y] unless x == SIZE/2 || y == SIZE/2
        end
      end
    end

    (1..PLAYERS).each do
      rob = []
      rob_internal = []
      (1..ROBOTS).each do
        rob << [ find_empty, 0 ]
        rob_internal << [ 0, [], '[]', nil ]
      end
      @players << rob
      @players_internal << rob_internal
    end

    (1..COINS).each do
      @coins << [ find_empty, rand(MAX_VALUE) + 1]
    end
  end

  def find_empty
    x = rand(SIZE)
    y = rand(SIZE)
    while gen_map.dig(x,y,:t) != ' '
      x = rand(SIZE)
      y = rand(SIZE)
    end
    [x,y]
  end

  def gen_map
    data = []
    (1..SIZE).each{data << [ { t: ' ' } ] * SIZE}

    @walls.each do |pos|
      data[pos[0]][pos[1]] = { t: 'X' }
    end

    @hq.each_with_index do |pos,i|
      data[pos[0]][pos[1]] = { t: 'H', team: i }
    end

    @players.each_with_index do |robots, pl|
      robots.each_with_index do |robot,rob|
        pos = robot[0]
        data[pos[0]][pos[1]] = { t: 'R', team: pl, id: rob, inv: robot[1] }
      end
    end

    @coins.each_with_index do |coin, i|
      pos = coin[0]
      data[pos[0]][pos[1]] = { t: 'B', id: i, value: coin[1] }
    end

    data
  end

  def move_robot(team_id, robot_id, dx, dy, force)
    cx = @players[team_id][robot_id][0][0]
    cy = @players[team_id][robot_id][0][1]
    inventory = @players[team_id][robot_id][1]

    cx += dx
    cy += dy

    return if cx<0 || cy<0 || cx>=SIZE || cy>=SIZE

    destination = gen_map.dig(cx,cy,:t)

    if force
      case destination
      when 'R' then
        @players.each do |player|
          player.each do |robot|
            pos = robot[0]
            if cx == pos[0] && cy == pos[1]
              robot[0] = find_empty
              if STEALING
                @players[team_id][robot_id][1] += robot[1]
                robot[1] = 0
              end
            end
          end
        end
      end
    else
      case destination
      when ' ' then
        @players[team_id][robot_id][0][0] = cx
        @players[team_id][robot_id][0][1] = cy
        if inventory != 0 && (cx-@hq[team_id][0]).abs <= 1 && (cy-@hq[team_id][1]).abs <= 1
          @score[team_id] += inventory
          @players[team_id][robot_id][1] = 0

          p @score
        end
      when 'B' then
        @players[team_id][robot_id][0][0] = cx
        @players[team_id][robot_id][0][1] = cy
        @coins.each_with_index do |coin, i|
          pos = coin[0]
          if cx == pos[0] && cy == pos[1]
            @players[team_id][robot_id][1] += coin[1]
            @coins[i] = [ find_empty, rand(MAX_VALUE) + 1]
          end
        end
      end
    end
  end

  def set_state(team_id, robot_id, new_state, new_memory)
    data = @players_internal[team_id][robot_id]
    if new_state
      data[0] = new_state
    end

    if new_memory
      data[1] = new_memory
    end
  end

  def change_data(team_id, data)
    robot_id = data['robot_id']
    if robot_id && robot_id.is_a?(Integer) && robot_id >= 0 && robot_id < ROBOTS
      set_error(team_id, robot_id, nil)
      robot = @players_internal[team_id][robot_id]
      robot[2] = "#{data['new_code']}"
      if robot[3]
        robot[3].send_data("EXIT\n")
        robot[3].close_connection_after_writing
        robot[3] = nil
      end
      if data['language'] == 'js'
        runner = EventMachine.popen('docker run --rm -i js-runner', CodeRunner, robot[2], robot_id, team_id)
      else
        runner = EventMachine.popen('docker run --rm -i ruby-runner', CodeRunner, robot[2], robot_id, team_id)
      end
      robot[3] = runner
    end
  end

  def change_state(team_id, data)
    robot_id = data['robot_id']
    new_state = data['new_state']

    if robot_id && robot_id.is_a?(Integer) && robot_id >= 0 && robot_id < ROBOTS
      if new_state && new_state.is_a?(Integer) && new_state >= 0 && new_state < 10
        robot = @players_internal[team_id][robot_id]
        robot[0] = data['new_state'].to_i
      end
    end
  end

  def set_error(team_id, robot_id, error_details)
    @error_log[team_id] ||= []
    @error_log[team_id][robot_id] = error_details
  end

  def gen_runner_data(team_id, robot_id)
    {
      robot_id: robot_id,
      team_id: team_id,
      state: @players_internal[team_id][robot_id][0],
      memory: @players_internal[team_id][robot_id][1],
      map: gen_map,
      hqs: @hq.map{|hq| { x: hq[0], y: hq[1] } },
      robots: @players.map{ |pl| pl.map { |robot| { x: robot[0][0], y: robot[0][1], inv: robot[1] } } },
      coins: @coins.map{|coin| { x: coin[0][0], y: coin[0][1], value: coin[1] } }
    }
  end

  def get_send_data(team_id)
    {
      type: 'map',
      data: gen_map,
      scores: @score,
      internal: @players_internal[team_id].map{|r| [r[0], r[1]] },
      errors: @error_log[team_id],
      time: TIME - (Time.new - @start_time)
    }
  end

  def send(ws, team_id)
    ws.send(get_send_data(team_id).to_json)
  end

  def send_codes(ws, team_id)
    ws.send({
      type: 'code',
      data: @players_internal[team_id].map{|robot| robot[2]}
    }.to_json)
  end

  def start_runners
    @players_internal.each_with_index do |robots, team_id|
      robots.each_with_index do |robot,robot_id|
        set_error(team_id, robot_id, nil)
        runner = EventMachine.popen('docker run --rm -i ruby-runner', CodeRunner, robot[2], robot_id, team_id)
        robot[3] = runner
      end
    end
  end
end

class CodeRunner < EventMachine::Connection
  include EM::P::LineProtocol

  def initialize(code, robot, team)
    @code = code
    @robot = robot
    @team = team
  end

  def post_init
    send_data @code + "\n__END__CODE__\n"
  end

  def receive_line(data)
    if data.start_with?("READY")
      next_step($map)
    else
      response = JSON.parse(data) rescue nil
      if response.is_a?(Array)
        case response[0]
          when 'up' then $map.move_robot(@team, @robot, 0, -1, false)
          when 'down' then $map.move_robot(@team, @robot, 0, 1, false)
          when 'left' then $map.move_robot(@team, @robot, -1, 0, false)
          when 'right' then $map.move_robot(@team, @robot, 1, 0, false)
          when 'UP' then $map.move_robot(@team, @robot, 0, -1, true)
          when 'DOWN' then $map.move_robot(@team, @robot, 0, 1, true)
          when 'LEFT' then $map.move_robot(@team, @robot, -1, 0, true)
          when 'RIGHT' then $map.move_robot(@team, @robot, 1, 0, true)
          when 'error' then $map.set_error(@team, @robot, response)
        end

        new_state = nil
        if response[1] && response[1].is_a?(Integer) && response[1]>=0 && response[1]<10
          new_state = response[1].to_i
        end

        memory = nil
        if response[2] && response[2].is_a?(Array) && response[2].length<=10 && response[2].all?{|r| r.is_a?(Integer)}
          memory = response[2]
        end

        $map.set_state(@team, @robot, new_state, memory)
      end
      EventMachine.add_timer(TICK_LENGTH) do
        next_step($map)
      end
    end
  end

  def unbind
    puts "Robot #{@team} / #{@robot}: quit with status: #{get_status.exitstatus}"
  end

  def next_step(map)
    send_data map.gen_runner_data(@team, @robot).to_json + "\n"
  end
end

$map = Map.new

EM.run do
  $map.start_runners

  EventMachine::PeriodicTimer.new(1) do
    data = $map.get_send_data(0)
    p data[:time]
    if data[:time] < 0
      puts 'Finished';
      p data[:scores]
      EventMachine::stop_event_loop
    end
  end

  WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 8080) do |ws|
    timer = nil

    ws.onopen do
      puts "Client connected"
      ws.send({type: 'welcome'}.to_json)
    end

    ws.onmessage do |msg, type|
      puts "Received message: #{msg}"

      data = JSON.parse(msg) rescue nil

      if data
        case data['type']
        when 'login' then
          PLAYER_CODES.each_with_index do |code, team_id|
            if code == data['code']
              $map.send_codes(ws, team_id)
              timer = EventMachine::PeriodicTimer.new(1) do
                $map.send(ws, team_id)
              end
            end
          end
        when 'code' then
          PLAYER_CODES.each_with_index do |code, team_id|
            if code == data['code']
              $map.change_data(team_id, data)
            end
          end
        when 'state' then
          PLAYER_CODES.each_with_index do |code, team_id|
            if code == data['code']
              $map.change_state(team_id, data)
            end
          end
        end
      end
    end

    ws.onclose do
      timer.cancel if timer
      puts "Client disconnected"
    end
  end
end
