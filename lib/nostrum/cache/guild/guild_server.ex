defmodule Nostrum.Cache.Guild.GuildServer do
  @moduledoc false

  use GenServer, restart: :transient

  alias Nostrum.Cache.Guild.GuildRegister
  alias Nostrum.Struct.Guild
  alias Nostrum.Util

  require Logger

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
    with {:ok, pid} <- GuildRegister.lookup(id), do: GenServer.call(pid, request)
  end

  def cast(id, request) do
    with {:ok, pid} <- GuildRegister.lookup(id), do: GenServer.cast(pid, request)
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

    results =
      for {_t, {:ok, {k, v}}} <- Task.yield_many(tasks), into: %{} do
        {k, v}
      end

    Map.merge(guild, results)
  end

  @doc false
  def update(guild) do
    call(guild.id, {:update, guild})
  end

  # Uses a selector function to select certain fields from the guild state.
  @doc false
  @spec select(Guild.id(), (Guild.t() -> any)) :: any
  def select(guild_id, fun) do
    call(guild_id, {:select, fun})
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

  def handle_call({:select, fun}, _from, state) do
    {:reply, fun.(state), state}
  end

  def handle_call({:update, guild}, _from, state) do
    new_guild =
      state
      |> Map.from_struct()
      |> Map.merge(guild)

    new_guild_struct = struct(Guild, new_guild)

    {:reply, {state, new_guild_struct}, new_guild_struct}
  end

  def handle_call({:delete}, _from, state) do
    {:stop, :normal, state, %{}}
  end

  # TODO: Handle missing keys
  def handle_call({:create, :member, guild_id, member}, _from, state) do
    {new_members, _, member} =
      list_upsert_when(state.members, member, fn m -> m.user.id === member.user.id end)

    {:reply, {guild_id, member}, %{state | members: new_members}}
  end

  def handle_call({:update, :member, guild_id, new_partial_member}, _from, state) do
    {new_members, old_member, new_member} =
      list_upsert_when(state.members, new_partial_member, fn m ->
        m.user.id === new_partial_member.user.id
      end)

    {:reply, {guild_id, old_member, new_member}, %{state | members: new_members}}
  end

  def handle_call({:delete, :member, guild_id, user}, _from, state) do
    {new_members, deleted_member} =
      list_delete_when(state.members, fn m -> m.user.id === user.id end)

    {:reply, {guild_id, deleted_member}, %{state | members: new_members}}
  end

  def handle_call({:create, :channel, channel}, _from, state) do
    {new_channels, _, channel} =
      list_upsert_when(state.channels, channel, fn c -> c.id === channel.id end)

    {:reply, channel, %{state | channels: new_channels}}
  end

  def handle_call({:update, :channel, channel}, _from, state) do
    {new_channels, old_channel, new_channel} =
      list_upsert_when(state.channels, channel, fn c -> c.id === channel.id end)

    {:reply, {old_channel, new_channel}, %{state | channels: new_channels}}
  end

  def handle_call({:delete, :channel, channel_id}, _from, state) do
    {new_channels, deleted_channel} =
      list_delete_when(state.channels, fn c -> c.id === channel_id end)

    {:reply, deleted_channel, %{state | channels: new_channels}}
  end

  def handle_call({:create, :role, guild_id, role}, _from, state) do
    {new_roles, _, role} = list_upsert_when(state.roles, role, fn r -> r.id === role.id end)
    {:reply, {guild_id, role}, %{state | roles: new_roles}}
  end

  def handle_call({:update, :role, guild_id, role}, _from, state) do
    {new_roles, old_role, new_role} =
      list_upsert_when(state.roles, role, fn r -> r.id === role.id end)

    {:reply, {guild_id, old_role, new_role}, %{state | roles: new_roles}}
  end

  def handle_call({:delete, :role, guild_id, role_id}, _from, state) do
    {new_roles, deleted_role} = list_delete_when(state.roles, fn r -> r.id === role_id end)
    {:reply, {guild_id, deleted_role}, %{state | roles: new_roles}}
  end

  def handle_call({:update, :emoji, guild_id, emojis}, _from, state) do
    old_emojis = state.emojis
    {:reply, {guild_id, old_emojis, emojis}, %{state | emojis: emojis}}
  end

  def handle_cast({:member, :chunk, member}, state) do
    {new_members, _, _} =
      list_upsert_when(state.members, member, fn m -> m.user.id === member.user.id end)

    {:noreply, %{state | members: new_members}}
  end

  @spec list_upsert_when([struct], struct, (struct -> boolean), [struct]) ::
          {[struct], old :: struct | nil, new :: struct}
  defp list_upsert_when(list, value, fun, acc \\ [])

  defp list_upsert_when([], value, _, acc) do
    {acc ++ [value], nil, value}
  end

  defp list_upsert_when([head | list], value, fun, acc) do
    if fun.(head) do
      new_head =
        Map.merge(head, value, fn
          _k, v1, nil -> v1
          _k, _v1, v2 -> v2
        end)

      {acc ++ [new_head | list], head, new_head}
    else
      list_upsert_when(list, value, fun, acc ++ [head])
    end
  end

  @spec list_delete_when(list, (any -> boolean), list) :: {list, deleted_item :: any | nil}
  defp list_delete_when(list, id, acc \\ [])

  defp list_delete_when([], _, acc), do: {acc, nil}

  defp list_delete_when([head | list], fun, acc) do
    if fun.(head) do
      {acc ++ list, head}
    else
      list_delete_when(list, fun, acc ++ [head])
    end
  end
end
