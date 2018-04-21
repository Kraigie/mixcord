defmodule Nostrum.Struct.Guild.ChannelTest do
  use ExUnit.Case, async: true

  alias Nostrum.Struct.Guild.Channel

  doctest Channel

  describe "String.Chars" do
    test "matches `mention/1`" do
      channel = %Nostrum.Struct.Guild.Channel{id: 381_889_573_426_429_952}

      assert(to_string(channel) === Channel.mention(channel))
    end
  end
end
