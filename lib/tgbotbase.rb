module TGBotBase
  
  class ConfigFileNotFound < RuntimeError
  end

  class TGBotBase
  
    attr_reader :bot

    DEFAULT_DISCONNECT_SLEEP_TIME = 60

    def initialize(logger:,
                   config_path: nil,
                   config_name: nil,
                   mute_before: nil,
                   disconnect_sleep_time: DEFAULT_DISCONNECT_SLEEP_TIME)
      @logger = logger
      @mute_before = mute_before
      @disconnect_sleep_time = disconnect_sleep_time
      
      @config_path = config_path ||
                     get_config_file_path(config_name)
      File.open(@config_path, 'r') do |file|
        @config = YAML.load(file)
      end

      @bot_name = @config['bot_name']
    end

    def run
      while true
        begin
          Telegram::Bot::Client.run(config['telegram_token'],
                                    logger: @logger) do |bot|
            @bot = bot
            bot_user_data = bot.api.get_me
            @bot_user_id = nil
            if !bot_user_data || !bot_user_data['ok']
              self.logger.error("Can't get bot id");
              break;
            else
              @bot_user_id = bot_user_data['result']['id'].to_i;
            end
            
            @bot.listen do |message|
              self.process_message(message: message)
            end
          end
        rescue Telegram::Bot::Exceptions::ResponseError => e
          logger.error "Disconnected: #{e.message}"
          sleep @disconnect_sleep_time
        rescue Faraday::ConnectionFailed => e
          logger.error "Disconnected: #{e.message}"
          sleep @disconnect_sleep_time
        rescue RuntimeError => e
          logger.error "Error: #{e.message}\n#{e.backtrace}"
          raise
        end
      end
    end
    
    def process_message(message:)
      # case message
      # when Telegram::Bot::Types::InlineQuery
      # when Telegram::Bot::Types::CallbackQuery      
      # when Telegram::Bot::Types::Message
      #   if message.text == nil
      #     if message.sticker
      #     end
      #   else
      #     command = parse_command_line(message.text)
      #   end
      # end
    end
    
    def parse_command_line(line)
      if line =~ /\A\s*\/([a-z][a-z0-9_-]+)(?:@#{@bot_name})?(?:\s+(.*))?\z/i
        return { command: Regexp.last_match[1], parameter: Regexp.last_match[2] }
      else
        return nil
      end
    end
    
    def send_message(chat_id:, text:, source_time: nil)
      if @mute_before && source_time && source_time < @mute_before
        self.logger.debug("Mute old message,
                          chat_id: #{chat_id},
                          text: #{text}")
      else
        self.logger.debug("Sending message, chat_id: #{chat_id}, text: #{text}")
        @bot.api.send_message(chat_id: chat_id, text: text)
      end
    end

    def send_message_answer(to_message:, text:)
      send_message(chat_id: to_message.chat_id,
                   text: text,
                   source_time: to_message.date)
    end
    
    protected
    
    def logger
      @logger
    end
    
    def config
      @config
    end
    
    def bot_name
      @bot_name
    end
    
    private
    
    def get_config_file_path(config_file_name)
      [__dir__, '/usr/local/etc/', '/etc/'].each do |config_dir|
        config_file_path = File.join(config_dir, config_file_name)
        if File.exist?(config_file_path)
          return config_file_path
        end
      end
      raise ConfigFileNotFound.new("Config file " + config_file_name +
                                   " not found")
    end
    
  end

  
  class TGBotTypical < TGBotBase
    
    attr_reader :database_file
    
    def initialize(logger:, config_path: nil, mute_before: nil)
      super
      @database_file = config['database_file']
    end
    
    # def run
    # begin
    #   SQLite3::Database.new @database_file do |db|
    #     @db = db
    #     @db.results_as_hash = true
    #     super
    #   end
    # rescue RuntimeError => e
    #   @logger.error(e.message)
    # end
    # end
    
    def create_db
      self.logger.debug("Creating database #{@database_file}")
      SQLite3::Database.new(@database_file) do |db|
        db.transaction
        create_db_content(db)
        db.commit
      end
    end
    
    # def database_file
    #   @database_file
    # end
    
    # def db
    #   @db
    # end
    
    protected
    
    def create_db_content(db)
      # db.execute <<-EOF
      #   CREATE TABLE #{TABLE_CHANNELS} (
      #     channel_id INTEGER UNIQUE NOT NULL,
      #     is_enabled BOOLEAN DEFAULT 1
      #   );
      # EOF
    end
    
  end

end

