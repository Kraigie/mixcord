defmodule Nostrum.Struct.Emoji do
  @moduledoc ~S"""
  Struct representing a Discord emoji.

  ## Using Emojis in Messages

  A `Nostrum.Struct.Emoji` can be used in message content using the `String.Chars`
  protocol or `mention/1`.

  ```Elixir
  emoji = %Nostrum.Struct.Emoji{id: 437093487582642177, name: "foxbot"}
  Nostrum.Api.create_message!(184046599834435585, "#{emoji}")
  %Nostrum.Struct.Message{}

  emoji = %Nostrum.Struct.Emoji{id: 436885297037312001, name: "tealixir"}
  Nostrum.Api.create_message!(280085880452939778, "#{Nostrum.Struct.Emoji.mention(emoji)}")
  %Nostrum.Struct.Message{}
  ```

  ## Using Emojis in the Api

  A `Nostrum.Struct.Emoji` can be used in `Nostrum.Api` by using its api name
  or the struct itself.

  ```Elixir
  emoji = %Nostrum.Struct.Emoji{id: 436885297037312001, name: "tealixir"}
  Nostrum.Api.create_reaction(381889573426429952, 436247584349356032, Nostrum.Struct.Emoji.api_name(emoji))
  {:ok}

  emoji = %Nostrum.Struct.Emoji{id: 436189601820966923, name: "elixir"}
  Nostrum.Api.create_reaction(381889573426429952, 436247584349356032, emoji)
  {:ok}
  ```

  See `t:Nostrum.Struct.Emoji.api_name/0` for more information.
  """

  alias Nostrum.Struct.Snowflake
  alias Nostrum.Struct.User
  alias Nostrum.Util

  defstruct [
    :id,
    :name,
    :user,
    :require_colons,
    :managed,
    :animated,
    :roles
  ]

  defimpl String.Chars do
    def to_string(emoji), do: @for.mention(emoji)
  end

  @typedoc ~S"""
  Emoji string to be used with the Discord API.

  Some API endpoints take an `emoji`. If it is a custom emoji, it must be
  structured as `"id:name"`. If it is an unicode emoji, it can be structured
  as any of the following:

    * `"name"`
    * A base 16 unicode emoji string.

  `api_name/1` is a convenience function that returns a `Nostrum.Struct.Emoji`'s
  api name.

  ## Examples

  ```Elixir
  # Custom Emojis
  "nostrum:431890438091489"

  # Unicode Emojis
  "≡ƒæì"
  "\xF0\x9F\x98\x81"
  "\u2b50"
  ```
  """
  @type api_name :: String.t()

  @typedoc "Id of the emoji"
  @type id :: Snowflake.t() | nil

  @typedoc "Name of the emoji"
  @type name :: String.t()

  @typedoc "Roles this emoji is whitelisted to"
  @type roles :: [Snowflake.t()] | nil

  @typedoc "User that created this emoji"
  @type user :: User.t() | nil

  @typedoc "Whether this emoji must be wrapped in colons"
  @type require_colons :: boolean | nil

  @typedoc "Whether this emoji is managed"
  @type managed :: boolean | nil

  @typedoc "Whether this emoji is animated"
  @type animated :: boolean | nil

  @type t :: %__MODULE__{
          id: id,
          name: name,
          roles: roles,
          user: user,
          require_colons: require_colons,
          managed: managed,
          animated: animated
        }

  @doc ~S"""
  Formats an `Nostrum.Struct.Emoji` into a mention.

  ## Examples

  ```Elixir
  iex> emoji = %Nostrum.Struct.Emoji{id: 436885297037312001, name: "tealixir"}
  ...> Nostrum.Struct.Emoji.mention(emoji)
  "<:tealixir:436885297037312001>"
  ```
  """
  @spec mention(t) :: String.t()
  def mention(emoji)
  def mention(%__MODULE__{id: nil, name: name}), do: name
  def mention(%__MODULE__{animated: true, id: id, name: name}), do: "<a:#{name}:#{id}>"
  def mention(%__MODULE__{id: id, name: name}), do: "<:#{name}:#{id}>"

  @doc ~S"""
  Formats an emoji struct into its `t:Nostrum.Struct.Emoji.api_name/0`.

  ## Examples

  ```Elixir
  iex> emoji = %Nostrum.Struct.Emoji{id: 437093487582642177, name: "foxbot"}
  ...> Nostrum.Struct.Emoji.api_name(emoji)
  "foxbot:437093487582642177"
  ```
  """
  @spec api_name(t) :: api_name
  def api_name(emoji)
  def api_name(%__MODULE__{id: nil, name: name}), do: name
  def api_name(%__MODULE__{id: id, name: name}), do: "#{name}:#{id}"

  @doc false
  def p_encode do
    %__MODULE__{}
  end

  @doc false
  def to_struct(map) do
    new =
      map
      |> Map.new(fn {k, v} -> {Util.maybe_to_atom(k), v} end)
      |> Map.update(:id, nil, &Util.cast(&1, Snowflake))
      |> Map.update(:roles, nil, &Util.cast(&1, {:list, Snowflake}))
      |> Map.update(:user, nil, &Util.cast(&1, {:struct, User}))

    struct(__MODULE__, new)
  end
end
