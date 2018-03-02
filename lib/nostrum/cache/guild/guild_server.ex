defmodule Nostrum.Cache.Guild.GuildServer do
  @moduledoc """
  Module for interacting with Guild Servers.
  """

  use GenServer, restart: :transient

  alias Nostrum.Cache.Guild.GuildRegister
  alias Nostrum.Cache.Mapping.ChannelGuild
  alias Nostrum.Struct.Guild
  alias Nostrum.Struct.Guild.{Channel, Member, Role}
  alias Nostrum.Util

  require Logger

  @typedoc """
  Represents different ways to search for a guild.

  ## Examples
    - Search by `t:Nostrum.Struct.Guild.id/0`
    ```Elixir
    GuildServer.get(id: 666666666666666)
    ```
    - Search by `t:Nostrum.Struct.Guild.TextChannel.id/0`
    ```Elixir
    GuildServer.get(channel_id: 314159265358979)
    ```
    - Search via `Nostrum.Struct.Message`
    ```Elixir
    msg = Nostrum.Api.create_message!(1618033988731, "Drake confirmed British")
    GuildServer.get(msg)
    ```
  """
  @type search_criteria :: [id: integer] |
                           [channel_id: integer] |
                           [message: Nostrum.Struct.Message.t]

  @typedoc """
  Represents different ways to get a value from a guild.

  Same as `t:search_criteria/0`, but takes an additional key parameter.
  Keys can be found in `Nostrum.Struct.Guild`
  """
  @type search_criteria_with_key :: [id: integer, key: key :: atom] |
                                    [channel_id: integer, key: key :: atom] |
                                    [message: Nostrum.Struct.Message.t, key: key :: atom]

  @typedoc """
  Transform for a guild.

  The function is passed a `Nostrum.Struct.Guild.t` struct.
  """
  @type transform :: (Guild.t -> term)

  @typedoc """
  Represents different ways to transform a guild.

  Same as `t:search_criteria/0`, but takes an additional transform parameter.
  See `transform/1` for an example.
  """
  @type search_criteria_with_transform :: [id: integer, transform: transform] |
                                          [channel_id: integer, transform: transform] |
                                          [message: Nostrum.Struct.Message.t, transform: transform]

  @doc """
  Retrieves a stream of all guilds.

  This will introduce a very large binary into the caller process. Consider
  running this method inside its own task.

  If you just need to get a specific key, consider using
  `get_value_all/1`

  ## Example
  ```Elixir
  Nostrum.Cache.Guild.GuildServer.all
  |> Enum.take_every(3)
  |> D3L3T3_GU1LD
  ```
  """
  @spec all() :: Enumerable.t
  def all do
    transform_all(&(&1))
  end

  @doc """
  Retrieves a stream of values from all guilds.

  ## Parameter
    - `key` - Value to get from all guilds.

  ## Example
  ```Elixir
  names =
  Nostrum.Cache.GuildServer.get_value_from_all(:name)
  |> Enum.filter(&is_weeb?)
  |> D3L3T3_GU1LD5
  ```
  """
  @spec get_value_from_all(key :: atom) :: Enumerable.t
  def get_value_from_all(key) when is_atom(key) do
    transform_all(&Map.get(&1, key))
  end

  @doc ~S"""
  Retrieves a guild from the cache.

  ## Parameters
    - `search_criteria` - The criteria used to search. See `t:search_criteria/0` for more info.

  ## Example
  ```Elixir
  case Nostrum.Cache.Guild.GuildServer.get(id: 1234567891234789) do
    {:ok, guild} -> "Guild has #{length(guild.members)} members"
    {:error, _reason} -> "Guild is MIA"
  end
  ```
  """
  @spec get(search_criteria) :: {:error, reason :: atom} | {:ok, Nostrum.Struct.Guild.t}
  def get(search_criteria) do
    transform(search_criteria ++ [transform: &(&1)])
  end

  @doc ~S"""
  Retrieves a guild from the cache.

  See `Nostrum.Cache.Guild.GuildServer.get/1` for usage.

  Raises `Nostrum.Error.CacheError` if unable to find the guild.
  """
  @spec get!(search_criteria) :: no_return | {Nostrum.Struct.Guild.t}
  def get!(search_criteria) do
    get(search_criteria)
    |> Util.bangify_find(search_criteria, __MODULE__)
  end

  @doc ~S"""
  Retrieves a value from a guild in the cache.

  This method should be preferred over the `get/1`
  method in the event that you need only one kv pair from the guild.

  ## Parameters
    - `search_criteria_with_key` - The criteria used to search. See
    `t:search_criteria_with_key/0` for more info.

  ## Example
  ```Elixir
  case Nostrum.Cache.Guild.Guildserver.get_value(id: 69696969696969, key: :name) do
    {:ok, sick_guild_name} -> "#{sick_guild_name} is sick"
    {:error, reason} -> "Whatchu' searchin' for fam?"
  end
  ```
  """
  @spec get_value(search_criteria_with_key) :: {:error, reason :: atom} |
                                               {:ok, term}
  def get_value(id: id, key: k) when is_atom(k) do
    transform(id: id, transform: &Map.get(&1, k)) |> check_missing_key
  end

  def get_value(channel_id: c_id, key: k) when is_atom(k) do
    transform(channel_id: c_id, transform: &Map.get(&1, k)) |> check_missing_key
  end

  def get_value(message: %Nostrum.Struct.Message{channel_id: c_id}, key: k) do
    c_id_int = String.to_integer(c_id)
    transform(channel_id: c_id_int, transform: &Map.get(&1, k)) |> check_missing_key
  end

  @doc """
  Retrieves a value from a guild in the cache.

  See `Nostrum.Cache.Guild.GuildServer.get_value!/2` for usage.

  Raises `Nostrum.Error.CacheError` if unable to find the guild or key.
  """
  @spec get_value!(search_criteria_with_key) :: no_return | term
  def get_value!(search_critera_with_key) do
    get_value(search_critera_with_key)
    |> bangify_key_search(search_critera_with_key[:key])
  end

  defp check_missing_key({:ok, nil}), do: {:error, :key_not_found}
  defp check_missing_key(ok), do: ok

  # REVIEW: Can/should we handle cache errors in a better way?
  defp bangify_key_search({:error, :key_not_found}, key),
    do: raise(Nostrum.Error.CacheError, key: key, cache_name: __MODULE__)
  defp bangify_key_search({:error, reason}, _key),
    do: raise(Nostrum.Error.CacheError, "ERROR: #{inspect reason}")
  defp bangify_key_search({:ok, val}, _key),
    do: val

  @doc ~S"""
  Retrieves a transformed guild from the cache.

  Returns the result of applying a given fun to the guild specified by the search
  criteria.

  This transform does not modify the cache and is performed entirely server side.
  This means that if you somehow cause an error to be thrown, the receiving guild
  process will die. The benefit is not "copying" guild binaries between
  processes which can be very big.

  ## Parameters
    - `search_criteria_with_transform` - The criteria used to search. See
    `t:search_criteria_with_transform/0` for more info.

  ## Example
  ```Elixir
  tf = fn guild -> Enum.any?(guild.members, &(Map.get(&1, :nick) == "The year is 20XX")) end
  {:ok, plays_fox?} = Nostrum.Cache.Guild.GuildServer.transform(id: 123, transform: tf)
  ```
  """
  @spec transform(search_criteria_with_transform) :: {:ok, term}
  def transform(id: id, transform: tf) do
    with {:ok, pid} <- GuildRegister.lookup(id),
    do: {:ok, GenServer.call(pid, {:transform, tf})}
  end

  def transform(channel_id: c_id, transform: tf) do
    with \
      {:ok, guild_id} <- ChannelGuild.get_guild(c_id),
      {:ok, guild_pid} <- GuildRegister.lookup(guild_id)
    do
      {:ok, GenServer.call(guild_pid, {:transform, tf})}
    end
  end

  def transform(message: %Nostrum.Struct.Message{channel_id: c_id}, transform: tf) do
    transform(channel_id: c_id, transform: tf)
  end

  @doc """
  Retrieves a stream of transformed guild values from the cache.

  Returns a stream of as the result of calling `transform` on every guild in the
  cache.

  See `transform/1` for usage.
  """
  @spec transform_all(transform) :: Enumerable.t
  def transform_all(transform) do
    Supervisor.which_children(GuildSupervisor)
    |> Stream.map(fn {_, pid, _, _} -> pid end)
    |> Task.async_stream(&GenServer.call(&1, {:transform, transform}))
    |> Stream.map(fn {:ok, term} -> term end)
  end

  @doc false
  # REVIEW: If a guild server crashes, it will be restarted with its initial state.
  def start_link(id, guild) do
    GenServer.start_link(__MODULE__, [id, guild])
  end

  @doc false
  def init([id, guild]) do
    case Registry.register(GuildRegistry, id, self()) do
      {:ok, _pid} ->
        {:ok, guild}
      {:error, error} ->
        # Causes start_link to return {:error, reason}
        {:stop, error}
    end
  end

  @doc false
  def child_spec do
    Supervisor.child_spec(__MODULE__, start: {__MODULE__, :start_link, []})
  end

  @doc false
  def call(id, request) do
    with {:ok, pid} <- GuildRegister.lookup(id),
    do: GenServer.call(pid, request)
  end

  def cast(id, request) do
    with {:ok, pid} <- GuildRegister.lookup(id),
    do: GenServer.cast(pid, request)
  end

  @doc false
  def create(guild) do
    # This returns {:ok, guild} or {:error reason}
    GuildRegister.create_guild_process(guild.id, guild)
  end

  def index_guild(guild) do
    # Index roles, members, and channels by their respective ids
    # Delegated to tasks so as to not replicate the guild process repeatedly
    tasks =
      for {key, index_by} <- [roles: [:id], members: [:user, :id], channels: [:id]] do
        Task.async(fn -> 
          Util.index_by_key(guild[key], key, index_by)
        end)
      end

    results = for {_t, {:ok, {k, v}}} <- Task.yield_many(tasks), into: %{} do
      {k, v}
    end

    Map.merge(guild, results)
  end

  @doc false
  def update(guild) do
    call(guild.id, {:update, guild})
  end

  @doc false
  def delete(guild_id) do
    call(guild_id, {:delete})
  end

  @doc false
  def member_add(guild_id, member) do
    call(guild_id, {:create, :member, guild_id, member})
  end

  @doc false
  def member_update(guild_id, member) do
    call(guild_id, {:update, :member, guild_id, member})
  end

  @doc false
  def member_remove(guild_id, user) do
    call(guild_id, {:delete, :member, guild_id, user})
  end

  def member_chunk(guild_id, user) do
    cast(guild_id, {:chunk, :member, user})
  end

  @doc false
  def channel_create(guild_id, channel) do
    call(guild_id, {:create, :channel, channel})
  end

  @doc false
  def channel_update(guild_id, channel) do
    call(guild_id, {:update, :channel, channel})
  end

  @doc false
  def channel_delete(guild_id, channel_id) do
    call(guild_id, {:delete, :channel, channel_id})
  end

  @doc false
  def role_create(guild_id, role) do
    call(guild_id, {:create, :role, guild_id, role})
  end

  @doc false
  def role_update(guild_id, role) do
    call(guild_id, {:update, :role, guild_id, role})
  end

  @doc false
  def role_delete(guild_id, role_id) do
    call(guild_id, {:delete, :role, guild_id, role_id})
  end

  @doc false
  def emoji_update(guild_id, emojis) do
    call(guild_id, {:update, :emoji, guild_id, emojis})
  end

  def handle_call({:transform, tf}, _from, state) do
    {:reply, tf.(state), state}
  end

  def handle_call({:update, guild}, _from, state) do
    new_guild = Map.merge(state, guild)
    {:reply, {state, new_guild}, new_guild}
  end

  def handle_call({:delete}, _from, state) do
    {:stop, :normal, state, %{}}
  end

  # TODO: Handle missing keys
  def handle_call({:create, :member, guild_id, member}, _from, state) do
    new_members = Map.put(state.members, member.user.id, member)
    {:reply, {guild_id, member}, %{state | members: new_members}}
  end

  def handle_call({:update, :member, guild_id, new_partial_member}, _from, state) do
    old_member = Map.get(state.members, new_partial_member.user.id, %Member{})
    new_member = Map.merge(old_member, new_partial_member)
    new_members = Map.put(state.members, new_partial_member.user.id, new_member)
    {:reply, {guild_id, old_member, new_member}, %{state | members: new_members}}
  end

  def handle_call({:delete, :member, guild_id, user}, _from, state) do
    {deleted_member, new_members} = Map.pop(state.members, user.id)
    {:reply, {guild_id, deleted_member}, %{state | members: new_members}}
  end

  def handle_call({:create, :channel, channel}, _from, state) do
    new_channels = Map.put(state.channels, channel.id, channel)
    {:reply, channel, %{state | channels: new_channels}}
  end

  def handle_call({:update, :channel, channel}, _from, state) do
    old_channel = Map.get(state.channels, channel.id, %Channel{})
    new_channel = Map.merge(old_channel, channel)
    new_channels = Map.put(state.channels, channel.id, new_channel)
    {:reply, {old_channel, new_channel}, %{state | channels: new_channels}}
  end

  def handle_call({:delete, :channel, channel_id}, _from, state) do
    {deleted_channel, new_channels} = Map.pop(state.channels, channel_id)
    {:reply, deleted_channel, %{state | channels: new_channels}}
  end

  def handle_call({:create, :role, guild_id, role}, _from, state) do
    new_roles = Map.put(state.roles, role.id, role)
    {:reply, {guild_id, role}, %{state | roles: new_roles}}
  end

  def handle_call({:update, :role, guild_id, role}, _from, state) do
    old_role = Map.get(state.roles, role.id, %Role{})
    new_role = Map.merge(old_role, role)
    new_roles = Map.put(state.roles, role.id, new_role)
    {:reply, {guild_id, old_role, new_role}, %{state | roles: new_roles}}
  end

  def handle_call({:delete, :role, guild_id, role_id}, _from, state) do
    {delete_role, new_roles} = Map.pop(state.roles, role_id)
    {:reply, {guild_id, delete_role}, %{state | roles: new_roles}}
  end

  def handle_call({:update, :emoji, guild_id, emojis}, _from, state) do
    old_emojis = state.emojis
    {:reply, {guild_id, old_emojis, emojis}, %{state | emojis: emojis}}
  end

  def handle_cast({:member, :chunk, member}, state) do
    new_members = Map.put(state.members, member.user.id, member)
    {:noreply, %{state | members: new_members}}
  end

end
