defmodule Nostrum.Struct.ApplicationCommandInteractionDataResolved do
  @moduledoc "Converted interaction payload."
  @moduledoc since: "0.5.0"

  alias Nostrum.Snowflake
  alias Nostrum.Struct.Channel
  alias Nostrum.Struct.Guild.Member
  alias Nostrum.Struct.Guild.Role
  alias Nostrum.Struct.User
  alias Nostrum.Util

  defstruct [:users, :members, :roles, :channels]

  @typedoc "IDs and corresponding users"
  @type users :: %{User.id() => User.t()} | nil

  @typedoc """
  IDs and corresponding partial members.

  These members are *missing* values on the following fields:

  - ``user``
  - ``deaf``
  - ``mute``

  The corresponding user data can be looked up in ``users``. For members that
  are part of this map, data for the corresponding user will always be included.
  """
  @type members :: %{User.id() => Member.t()} | nil

  @typedoc "IDs and corresponding roles"
  @type roles :: %{Role.id() => Role.t()} | nil

  @typedoc """
  IDs and corresponding partial channels.

  The channels in this map *only* have the following keys set:

  - ``id``
  - ``name``
  - ``type``
  - ``permissions``
  """
  @type channels :: %{Channel.id() => Channel.guild_text_channel()} | nil

  @typedoc "Resolved interaction data"
  @type t :: %__MODULE__{
          users: users,
          members: members(),
          roles: roles(),
          channels: channels()
        }

  # Parse the given mapping of strings to some corresponding arguments.
  # String snowflakes are transformed to integers, because our runtime
  # supports arbitrary-sized integers. Take that.
  defp map_parse(nil, _target_type) do
    nil
  end

  defp map_parse(structure, target_type) do
    structure
    |> Enum.map(fn {k, v} -> {Util.cast(k, Snowflake), Util.cast(v, target_type)} end)
    |> :maps.from_list()
  end

  @doc false
  def to_struct(map) do
    %__MODULE__{
      users: map_parse(map["users"], {:struct, User}),
      members: map_parse(map["members"], {:struct, Member}),
      roles: map_parse(map["roles"], {:struct, Role}),
      channels: map_parse(map["channels"], {:struct, Channel})
    }
  end
end
