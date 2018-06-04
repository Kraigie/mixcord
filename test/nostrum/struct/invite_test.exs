defmodule Nostrum.Struct.InviteTest do
  use ExUnit.Case, async: true

  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.Guild
  alias Nostrum.Struct.Invite
  alias Nostrum.Struct.Invite.Metadata
  alias Nostrum.Struct.User
  alias Nostrum.Util

  doctest Invite

  describe "Invite.to_struct/1" do
    setup do
      etf_invite = %{
        "code" => "0vCdhLbwjZZTWZLD",
        "guild" => %{
          "id" => "165176875973476352",
          "name" => "CS:GO Fraggers Only",
          "splash" => nil,
          "icon" => nil
        },
        "channel" => %{
          "id" => "165176875973476352",
          "name" => "illuminati",
          "type" => 0
        },
        "inviter" => %{
          "id" => "80351110224678912",
          "username" => "Nelly",
          "discriminator" => "1337",
          "avatar" => "8342729096ea3675442027381ff50dfe",
          "verified" => true,
          "email" => "nelly@discordapp.com"
        },
        "uses" => 0,
        "max_uses" => 0,
        "max_age" => 0,
        "temporary" => false,
        "created_at" => "2016-03-31T19:15:39.954000+00:00",
        "revoked" => false
      }

      invite = Invite.to_struct(etf_invite)

      {:ok, %{etf_invite: etf_invite, invite: invite}}
    end

    test "decodes to `t:Invite.t/0`", context do
      assert(%Invite{} = context.invite)
    end

    test "decodes guild correctly", context do
      expected = context.etf_invite["guild"] |> Util.cast({:struct, Guild})

      assert(expected === context.invite.guild)
    end

    test "decodes channel correctly", context do
      expected = context.etf_invite["channel"] |> Util.cast({:struct, Channel})

      assert(expected === context.invite.channel)
    end

    test "decodes inviter correctly", context do
      expected = context.etf_invite["inviter"] |> Util.cast({:struct, User})

      assert(expected === context.invite.inviter)
    end

    test "decodes metadata correctly", context do
      expected = context.etf_invite |> Util.cast({:struct, Metadata})

      assert(expected === context.invite.metadata)
    end
  end
end
