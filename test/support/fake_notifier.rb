# Records alerts instead of sending them. Swap in with `Alert.notifier = FakeNotifier.new`.
class FakeNotifier
  attr_reader :sent

  def initialize
    @sent = []
  end

  def deliver(text)
    @sent << text
    true
  end
end
