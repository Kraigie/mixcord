defmodule Nostrum.Struct.VoiceWSState do
  @moduledoc false

  defstruct [
    :guild_id,
    :session,
    :token,
    :conn,
    :conn_pid,
    :stream,
    :gateway,
    :identified,
    :last_heartbeat_send,
    :last_heartbeat_ack,
    :heartbeat_ack,
    :heartbeat_interval,
    :heartbeat_ref
  ]
end
