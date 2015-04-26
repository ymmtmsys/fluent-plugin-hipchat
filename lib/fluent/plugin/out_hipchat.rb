module Fluent
  class HipchatOutput < BufferedOutput
    COLORS = %w(yellow red green purple gray random)
    FORMAT = %w(html text)
    Fluent::Plugin.register_output('hipchat', self)

    config_param :api_token, :string
    config_param :api_version, :string, :default => 'v1'
    config_param :default_room, :string, :default => nil
    config_param :default_color, :string, :default => nil
    config_param :default_from, :string, :default => nil
    config_param :default_notify, :bool, :default => nil
    config_param :default_format, :string, :default => nil
    config_param :key_name, :string, :default => 'message'
    config_param :default_timeout, :time, :default => nil
    config_param :http_proxy_host, :string, :default => nil
    config_param :http_proxy_port, :integer, :default => nil
    config_param :http_proxy_user, :string, :default => nil
    config_param :http_proxy_pass, :string, :default => nil
    config_param :flush_interval, :time, :default => 1

    attr_reader :hipchat

    def initialize
      super
      require 'hipchat'
    end

    def configure(conf)
      super

      @default_room = conf['default_room']
      @default_from = conf['default_from'] || 'fluentd'
      @default_notify = conf['default_notify'] || 0
      @default_color = conf['default_color'] || 'yellow'
      @default_format = conf['default_format'] || 'html'
      @default_timeout = conf['default_timeout']

      proxy_uri = if conf['http_proxy_host']
                    "http://#{conf['http_proxy_user']}:#{conf['http_proxy_pass']}@#{conf['http_proxy_host']}:#{conf['http_proxy_port']}"
                  else
                    nil
                  end

      opts = {}
      opts[:http_proxy] = proxy_uri if proxy_uri
      opts[:api_version] = conf['api_version']
      @hipchat = HipChat::Client.new(conf['api_token'], opts)
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |(tag,time,record)|
        begin
          send_message(record) if record[@key_name]
          set_topic(record) if record['topic']
        rescue => e
          $log.error("HipChat Error:", :error_class => e.class, :error => e.message)
        end
      end
    end

    def send_message(record)
      room = record['room'] || @default_room
      from = record['from'] || @default_from
      message = record[@key_name]
      if record['notify'].nil?
        notify = @default_notify
      else
        notify = record['notify'] ? 1 : 0
      end
      color = COLORS.include?(record['color']) ? record['color'] : @default_color
      message_format = FORMAT.include?(record['format']) ? record['format'] : @default_format
      @hipchat.class.default_timeout(@default_timeout.to_i) unless @default_timeout.nil?
      @hipchat[room].send(from, message, :notify => (notify == 1), :color => color, :message_format => message_format)
    end

    def set_topic(record)
      room = record['room'] || @default_room
      from = record['from'] || @default_from
      topic = record['topic']
      @hipchat[room].topic(topic, :from => from)
    end
  end
end
