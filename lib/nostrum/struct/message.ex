defmodule Nostrum.Struct.Message do
  @moduledoc """
  Struct representing a Discord message.
  """

  alias Nostrum.Struct.Message.Attachment
  alias Nostrum.Struct.Message.Reaction
  alias Nostrum.Struct.Message.MessageActivity
  alias Nostrum.Struct.Message.MessageApplication
  alias Nostrum.Struct.{Embed, User, Snowflake}
  alias Nostrum.Util

  defstruct [
    :id,
    :channel_id,
    :author,
    :content,
    :timestamp,
    :edited_timestamp,
    :tts,
    :mention_everyone,
    :nonce,
    :pinned,
    :webhook_id,
    :type,
    :activity,
    :application,
    mention_roles: [],
    mentions: [],
    attachments: [],
    embeds: [],
    reactions: []
  ]

  @typedoc "The id of the message"
  @type id :: Snowflake.t

  @typedoc "The id of the channel"
  @type channel_id :: Snowflake.t

  @typedoc "The user struct of the author"
  @type author :: User.t

  @typedoc "The content of the message"
  @type content :: String.t

  @typedoc "When the message was sent"
  @type timestamp :: String.t

  @typedoc "When the message was edited"
  @type edited_timestamp :: String.t | nil

  @typedoc "Whether this was a TTS message"
  @type tts :: boolean

  @typedoc "Whether this messsage mentions everyone"
  @type mention_everyone :: boolean

  @typedoc "List of users mentioned in the message"
  @type mentions :: [User.t]

  @typedoc "List of roles ids mentioned in the message"
  @type mention_roles :: [Snowflake.t]

  @typedoc "List of attached files in the message"
  @type attachments :: [Attachment.t]

  @typedoc "List of embedded content in the message"
  @type embeds :: [Embed.t]

  @typedoc "List of reactions to the message"
  @type reactions :: [Reaction.t]

  @typedoc "Validates if a message was sent"
  @type nonce :: Snowflake.t | nil

  @typedoc "Whether this message is pinned"
  @type pinned :: boolean

  @typedoc "If the message is generated by a webhook, this is the webhook's id"
  @type webhook_id :: Snowflake.t | nil

  @typedoc """
  Message type

    * `0` - DEFAULT
    * `1` - RECIPIENT_ADD
    * `2` - RECIPIENT_REMOVE
    * `3` - CALL
    * `4` - CHANNEL_NAME_CHANGE
    * `5` - CHANNEL_ICON_CHANGE
    * `6` - CHANNEL_PINNED_MESSAGE
    * `7` - GUILD_MEMBER_JOIN
  """
  @type type :: integer

  @typedoc "Activity data that is sent with Rich Presence-related chat embeds"
  @type activity :: MessageActivity.t | nil

  @typedoc "Application data that is sent with Rich Presence-related chat embeds"
  @type application :: MessageApplication.t | nil

  @type t :: %__MODULE__{
    id: id,
    channel_id: channel_id,
    author: author,
    content: content,
    timestamp: timestamp,
    edited_timestamp: edited_timestamp,
    tts: tts,
    mention_everyone: mention_everyone,
    mentions: mentions,
    mention_roles: mention_roles,
    attachments: attachments,
    embeds: embeds,
    reactions: reactions,
    nonce: nonce,
    pinned: pinned,
    webhook_id: webhook_id,
    type: type,
    activity: activity,
    application: application
  }

  @doc false
  def p_encode do
    %__MODULE__{
      author: User.p_encode,
      mentions: [User.p_encode],
      embeds: [Embed.p_encode]
    }
  end

  @doc false
  def to_struct(map) do
    struct(__MODULE__, Util.safe_atom_map(map))
    |> Map.update(:id, nil, &Util.cast(&1, Snowflake))
    |> Map.update(:channel_id, nil, &Util.cast(&1, Snowflake))
    |> Map.update(:author, %{}, &Util.cast(&1, {:struct, User}))
    |> Map.update(:mentions, %{}, &Util.cast(&1, {:list, {:struct, User}}))
    |> Map.update(:mention_roles, [], &Util.cast(&1, {:list, Snowflake}))
    |> Map.update(:attachments, %{}, &Util.cast(&1, {:list, {:struct, Attachment}}))
    |> Map.update(:embeds, %{}, &Util.cast(&1, {:list, {:struct, Embed}}))
    |> Map.update(:reactions, %{}, &Util.cast(&1, {:list, {:struct, Reaction}}))
    |> Map.update(:nonce, nil, &Util.cast(&1, Snowflake))
    |> Map.update(:webhook_id, nil, &Util.cast(&1, Snowflake))
    |> Map.update(:activity, nil, &Util.cast(&1, {:struct, MessageActivity}))
    |> Map.update(:application, nil, &Util.cast(&1, {:struct, MessageApplication}))
  end
end
