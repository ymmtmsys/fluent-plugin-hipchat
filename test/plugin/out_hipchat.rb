require 'test_helper'
require 'fluent/plugin/out_hipchat'

class HipchatOutputTest < Test::Unit::TestCase
  def setup
    super
    Fluent::Test.setup
  end

  CONFIG = %[
    type hipchat
    api_token testtoken
    api_version v1
    default_room testroom
    default_from testuser
    default_color yellow
  ]

  CONFIG_FOR_PROXY = %[
    http_proxy_host localhost
    http_proxy_port 8080
    http_proxy_user user
    http_proxy_pass password
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::HipchatOutput) {
    }.configure(conf)
  end

  def test_default_message
    d = create_driver(<<-EOF)
                      type hipchat
                      api_token xxx
                      default_room testroom
                      EOF
    stub(d.instance.hipchat).rooms_message('testroom', 'fluentd', 'foo', 0, 'yellow', 'html')
    assert_equal d.instance.hipchat.instance_variable_get(:@token), 'xxx'
    d.emit({'message' => 'foo'})
    d.run
  end

  def test_set_default_timeout
    d = create_driver(<<-EOF)
                      type hipchat
                      api_token xxx
                      default_timeout 5
                      EOF
    stub(d.instance.hipchat).set_timeout(5)
    d.emit({'message' => 'foo'})
    d.run
  end

  def test_message
    d = create_driver
    stub(d.instance.hipchat['testroom']).send('testuser', 'foo', :notify => false, :color => 'red', :message_format => 'html')
    assert_equal d.instance.hipchat.instance_variable_get(:@token), 'testtoken'
    d.emit({'message' => 'foo', 'color' => 'red'})
    d.run
  end

  def test_message_override
    d = create_driver
    stub(d.instance.hipchat['my']).send('alice', 'aaa', :notify => true, :color => 'random', :message_format => 'text')
    d.emit(
      {
        'room' => 'my',
        'from' => 'alice',
        'message' => 'aaa',
        'notify' => true,
        'color' => 'random',
        'format' => 'text',
      }
    )
    d.run
  end

  def test_topic
    d = create_driver
    stub(d.instance.hipchat['testroom']).topic('foo', :from => 'testuser')
    d.emit({'topic' => 'foo'})
    d.run
  end

  def test_set_topic_response_error
    d = create_driver
    stub.instance_of(HipChat::Room).topic('foo', :from => 'testuser') {
      raise HipChat::UnknownResponseCode, "Unexpected 400 for room `testroom`"
    }
    stub($log).error("HipChat Error:", :error_class => HipChat::UnknownResponseCode, :error => "Unexpected 400 for room `testroom`")
    d.emit({'topic' => 'foo'})
    d.run
  end

  def test_send_message_response_error
    d = create_driver
    stub.instance_of(HipChat::Room).send('<abc>', 'foo', :notify => false, :color => 'yellow', :message_format => 'html') {
      raise HipChat::UnknownResponseCode, "Unexpected 400 for room `testroom`"
    }
    stub($log).error("HipChat Error:", :error_class => HipChat::UnknownResponseCode, :error => "Unexpected 400 for room `testroom`")
    d.emit({'from' => '<abc>', 'message' => 'foo'})
    d.run
  end

  def test_color_validate
    d = create_driver
    stub(d.instance.hipchat['testroom']).send('testuser', 'foo', :notify => 0, :color => 'yellow', :message_format => 'html')
    d.emit({'message' => 'foo', 'color' => 'invalid'})
    d.run
  end

  def test_http_proxy
    create_driver(CONFIG + CONFIG_FOR_PROXY)
    assert_equal 'localhost', HipChat::Client.default_options[:http_proxyaddr]
    assert_equal 8080, HipChat::Client.default_options[:http_proxyport]
    assert_equal 'user', HipChat::Client.default_options[:http_proxyuser]
    assert_equal 'password', HipChat::Client.default_options[:http_proxypass]
  end

  def test_api_version
    create_driver(CONFIG + CONFIG_FOR_PROXY)
    assert_equal 'https://api.hipchat.com/v1', HipChat::Client.base_uri
  end
end
