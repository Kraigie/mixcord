defmodule Nostrum.Voice.Session do
  @moduledoc false

  alias Nostrum.Cache.{ChannelCache, GuildCache}
  alias Nostrum.Constants
  alias Nostrum.Shard.Stage.Producer
  alias Nostrum.Struct.{VoiceState, VoiceWSState}
  alias Nostrum.Util
  alias Nostrum.Voice
  alias Nostrum.Voice.{Event, Payload}

  require Logger

  use GenServer

  @gateway_qs "/?v=4"

  @timeout_connect 10_000

  @timeout_ws_upgrade 10_000

  def start_link(%VoiceState{} = vs) do
    GenServer.start_link(__MODULE__, vs)
  end

  def init(args) do
    {:ok, nil, {:continue, args}}
  end

  def handle_continue(%VoiceState{} = voice, nil) do
    Logger.metadata(
      guild: ~s|"#{GuildCache.get!(voice.guild_id).name}"|,
      channel: ~s|"#{ChannelCache.get!(voice.channel_id).name}"|
    )

    [host, port] = String.split(voice.gateway, ":")

    {:ok, worker} =
      :gun.open(:binary.bin_to_list(host), String.to_integer(port), %{protocols: [:http]})

    {:ok, :http} = :gun.await_up(worker, @timeout_connect)
    stream = :gun.ws_upgrade(worker, @gateway_qs)
    await_ws_upgrade(worker, stream)

    state = %VoiceWSState{
      conn_pid: self(),
      conn: worker,
      guild_id: voice.guild_id,
      session: voice.session,
      token: voice.token,
      gateway: voice.gateway,
      last_heartbeat_ack: DateTime.utc_now(),
      heartbeat_ack: true
    }

    Logger.debug(fn -> "Voice Websocket connection up on worker #{inspect(worker)}" end)
    Voice.update_voice(voice.guild_id, session_pid: self())
    {:noreply, state}
  end

  defp await_ws_upgrade(worker, stream) do
    receive do
      {:gun_upgrade, ^worker, ^stream, [<<"websocket">>], _headers} ->
        :ok

      {:gun_error, ^worker, ^stream, reason} ->
        exit({:ws_upgrade_failed, reason})
    after
      @timeout_ws_upgrade ->
        Logger.error("Voice Websocket upgrade failed after #{@timeout_ws_upgrade / 1000} seconds")
        exit(:timeout)
    end
  end

  def get_ws_state(pid) do
    GenServer.call(pid, :ws_state)
  end

  def close_connection(pid) do
    GenServer.cast(pid, :close)
  end

  def set_speaking(pid, speaking) do
    GenServer.cast(pid, {:speaking, speaking})
  end

  def handle_info({:gun_ws, _worker, _stream, {:text, frame}}, state) do
    payload =
      frame
      |> :erlang.iolist_to_binary()
      |> Poison.decode!()
      |> Util.safe_atom_map()

    from_handle =
      payload.op
      |> Constants.atom_from_voice_opcode()
      |> Event.handle(payload, state)

    case from_handle do
      {new_state, reply} ->
        :ok = :gun.ws_send(state.conn, {:text, reply})
        {:noreply, new_state}

      new_state ->
        {:noreply, new_state}
    end
  end

  def handle_info({:gun_ws, _conn, _stream, {:close, errno, reason}}, state) do
    Logger.info("Voice websocket closed (errno #{errno}, reason #{inspect(reason)})")
    {:noreply, state}
  end

  def handle_info(
        {:gun_down, _conn, _proto, _reason, _killed_streams, _unprocessed_streams},
        state
      ) do
    # Try to cancel the internal timer, but
    # do not explode if it was already cancelled.
    :timer.cancel(state.heartbeat_ref)
    {:noreply, state}
  end

  def handle_info({:gun_up, worker, _proto}, state) do
    stream = :gun.ws_upgrade(worker, @gateway_qs)
    await_ws_upgrade(worker, stream)
    Logger.warn("Reconnected after connection broke")
    {:noreply, %{state | heartbeat_ack: true}}
  end

  def handle_cast(:heartbeat, %{heartbeat_ack: false, heartbeat_ref: timer_ref} = state) do
    Logger.warn("heartbeat_ack not received in time, disconnecting")
    {:ok, :cancel} = :timer.cancel(timer_ref)
    :gun.ws_send(state.conn, :close)
    {:noreply, state}
  end

  def handle_cast(:heartbeat, state) do
    {:ok, ref} =
      :timer.apply_after(state.heartbeat_interval |> trunc, :gen_server, :cast, [
        state.conn_pid,
        :heartbeat
      ])

    :ok = :gun.ws_send(state.conn, {:text, Payload.heartbeat_payload()})

    {:noreply,
     %{state | heartbeat_ref: ref, heartbeat_ack: false, last_heartbeat_send: DateTime.utc_now()}}
  end

  def handle_cast({:speaking, speaking}, state) do
    voice = Voice.update_voice(state.guild_id, speaking: speaking)
    speaking_update = Payload.speaking_update_payload(voice)
    payload = Payload.speaking_payload(voice)

    Producer.notify(Producer, speaking_update, state)

    :ok = :gun.ws_send(state.conn, {:text, payload})
    {:noreply, state}
  end

  def handle_cast(:close, state) do
    :gun.close(state.conn)
    {:noreply, state}
  end

  def handle_call(:ws_state, _from, state) do
    {:reply, state, state}
  end
end
