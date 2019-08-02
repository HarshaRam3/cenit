require 'rails_helper'

describe Setup::DelayedMessage do

  before :each do
    Setup::DelayedMessage.delete_all
    Setup::DelayedMessage.load_on_start
  end

  let! :delayed_message do
    Setup::DelayedMessage
  end

  context "when Redis client is present", if: Cenit::Redis.client? do
    it 'uses the Redis adapter' do
      expect(delayed_message.adapter).to be Setup::DelayedMessage::RedisAdapter
    end
  end

  context "when Redis client is not present", unless: Cenit::Redis.client? do
    it 'uses the Mongoid adapter' do
      expect(delayed_message.adapter).to be Setup::DelayedMessage::MongoidAdapter
    end
  end

  context "when adapter is NOT default Mongoid", unless: Setup::DelayedMessage.adapter == Setup::DelayedMessage::MongoidAdapter do

    it 'sets the load_on_start flag' do
      delayed_message.set_load_on_start(false)
      delayed_message.set_load_on_start(true)
      expect(delayed_message.load_on_start?).to be true
    end

    it 'removes load_on_start flag' do
      delayed_message.set_load_on_start(true)
      delayed_message.set_load_on_start(false)
      expect(delayed_message.load_on_start?).to be false
    end

    it 'executes the load_on_start block' do
      delayed_message.set_load_on_start(true)
      loaded = false
      delayed_message.adapter.load_on_start do
        loaded = true
      end
      expect(loaded).to be true
    end

    it 'does not execute the load_on_start block' do
      delayed_message.set_load_on_start(false)
      loaded = false
      delayed_message.adapter.load_on_start do
        loaded = true
      end
      expect(loaded).to be false
    end

    it 'remove the load_on_start flag when loading on start' do
      delayed_message.set_load_on_start(true)
      delayed_message.adapter.load_on_start
      expect(delayed_message.load_on_start?).to be false
    end

    it 'sets created delayed messages ready' do
      delayed_message.create(message: 'abc')
      record = nil
      delayed_message.for_each_ready(at: delayed_message.default_publish_at + 5.seconds) do |delayed_message|
        record = delayed_message
      end
      expect(record[:message]).to eq 'abc'
    end

    it 'sorts ready messages' do
      now = Time.now
      10.times do
        publish_at = now + rand(100).seconds
        delayed_message.create(
          message: publish_at.to_i,
          publish_at: publish_at
        )
      end
      before = nil
      delayed_message.for_each_ready(at: now + 100.seconds) do |delayed_message|
        if before
          expect(before[:message]).to be <= delayed_message[:message]
        end
        before = delayed_message
      end
    end

    it 'changes delayed messages order when updated' do
      now = Time.now
      delayed_message.create(message: 'first', publish_at: now + 10.seconds)
      second = delayed_message.create(message: 'second', publish_at: now + 20.seconds)
      second.update(publish_at: now)
      messages = []
      delayed_message.for_each_ready(at: now + 20.seconds) do |delayed_message|
        messages << delayed_message[:message]
      end
      expect(messages).to eq %w(second first)
    end

    it 'does not include not ready delayed messages' do
      now = Time.now
      delayed_message.create(message: 'first', publish_at: now)
      delayed_message.create(message: 'second', publish_at: now + 20.seconds)
      messages = []
      delayed_message.for_each_ready(at: now) do |delayed_message|
        messages << delayed_message[:message]
      end
      expect(messages).to eq %w(first)
    end

    it 'remove messages when destroyed' do
      now = Time.now
      first = delayed_message.create(message: 'first', publish_at: now)
      delayed_message.create(message: 'second', publish_at: now)
      first.destroy
      messages = []
      delayed_message.for_each_ready(at: now + 5.seconds) do |delayed_message|
        messages << delayed_message[:message]
      end
      expect(messages).to eq %w(second)
    end
  end
end
