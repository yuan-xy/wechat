module Wechat
  module ApiLoader
    def self.with(options)
      account = options[:account] || :default
      c = ApiLoader.config(account)

      token_file = options[:token_file] || c.access_token || '/var/tmp/wechat_access_token'
      js_token_file = options[:js_token_file] || c.jsapi_ticket || '/var/tmp/wechat_jsapi_ticket'

      if c.appid && c.secret && token_file.present?
        Wechat::Api.new(c.appid, c.secret, token_file, c.timeout, c.skip_verify_ssl, js_token_file)
      elsif c.corpid && c.corpsecret && token_file.present?
        Wechat::CorpApi.new(c.corpid, c.corpsecret, token_file, c.agentid, c.timeout, c.skip_verify_ssl, js_token_file)
      else
        puts <<-HELP
Need create ~/.wechat.yml with wechat appid and secret
or running at rails root folder so wechat can read config/wechat.yml
HELP
        exit 1
      end
    end

    @configs = nil

    def self.config(account = :default)
      return @configs[account.to_sym] unless @configs.nil?
      @configs ||= loading_config!
      @configs[account.to_sym]
    end

    private_class_method def self.loading_config!
      configs ||= config_from_file || config_from_environment

      configs.symbolize_keys!

      if defined?(::Rails)
        configs.each do |_, cfg|
          cfg[:access_token] ||= Rails.root.join('tmp/access_token').to_s
          cfg[:jsapi_ticket] ||= Rails.root.join('tmp/jsapi_ticket').to_s
        end
      end

      configs.each do |_, cfg|
        cfg[:timeout] ||= 20
        cfg[:have_session_class] = class_exists?('WechatSession')
      end

      # create config object using raw config data
      cfg_objs = {}
      configs.each do |account, cfg|
        cfg_objs[account] = OpenStruct.new(cfg)
      end
      cfg_objs
    end

    private_class_method def self.config_from_file
      if defined?(::Rails)
        config_file = Rails.root.join('config/wechat.yml')
        return resovle_config_file(config_file, Rails.env.to_s)
      else
        rails_config_file = File.join(Dir.getwd, 'config/wechat.yml')
        home_config_file = File.join(Dir.home, '.wechat.yml')
        if File.exist?(rails_config_file)
          rails_env = ENV['RAILS_ENV'] || 'default'
          config = resovle_config_file(rails_config_file, rails_env)
          if config.present? && (default = config[:default])  && (default['appid'] || default['corpid'])
            puts "Using rails project config/wechat.yml #{rails_env} setting..."
            return config
          end
        end
        if File.exist?(home_config_file)
          # Causion:
          # .wechat.yml and config/wechat.yml are the same format and rule now.
          # It supports env and multiple accounts also.
          # Old .wechat.yml maybe not work.

          rails_env = ENV['RAILS_ENV'] || 'default'
          return resovle_config_file(rails_config_file, rails_env)
        end
      end
    end

    private_class_method def self.resovle_config_file(config_file, env)
      if File.exist?(config_file)
        raw_data = YAML.load(ERB.new(File.read(config_file)).result)
        config = {}
        raw_data.each do |key, value|
          if key == env
            configs[:default] = value
          elsif m = /(.*?)_#{env}$/.match(key)
            configs[m[1].to_sym] = value
          end
        end
        config
      end
    end

    private_class_method def self.config_from_environment
      value = { appid: ENV['WECHAT_APPID'],
        secret: ENV['WECHAT_SECRET'],
        corpid: ENV['WECHAT_CORPID'],
        corpsecret: ENV['WECHAT_CORPSECRET'],
        agentid: ENV['WECHAT_AGENTID'],
        token: ENV['WECHAT_TOKEN'],
        access_token: ENV['WECHAT_ACCESS_TOKEN'],
        encrypt_mode: ENV['WECHAT_ENCRYPT_MODE'],
        timeout: ENV['WECHAT_TIMEOUT'],
        skip_verify_ssl: ENV['WECHAT_SKIP_VERIFY_SSL'],
        encoding_aes_key: ENV['WECHAT_ENCODING_AES_KEY'],
        jsapi_ticket: ENV['WECHAT_JSAPI_TICKET'],
        trusted_domain_fullname: ENV['WECHAT_TRUSTED_DOMAIN_FULLNAME'] }
      {default: value}
    end

    private_class_method def self.class_exists?(class_name)
      return Module.const_get(class_name).present?
    rescue NameError
      return false
    end
  end
end
