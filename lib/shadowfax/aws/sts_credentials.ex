defmodule Shadowfax.AWS.STSCredentials do
  @moduledoc """
  Provides AWS credentials using STS AssumeRole for temporary, auto-rotating credentials.

  This is more secure than long-lived IAM user credentials as it:
  - Issues temporary credentials (default: 1 hour expiration)
  - Automatically refreshes before expiration
  - Follows principle of least privilege
  - Provides audit trail via CloudTrail
  """

  use GenServer
  require Logger

  # Refresh 5 minutes before expiry
  @refresh_before_expiry_seconds 300
  # 1 hour
  @default_duration_seconds 3600

  @type t :: %__MODULE__{
          access_key_id: String.t() | nil,
          secret_access_key: String.t() | nil,
          session_token: String.t() | nil,
          expiration: DateTime.t() | nil,
          role_arn: String.t(),
          session_name: String.t(),
          duration_seconds: non_neg_integer()
        }

  defstruct [
    :access_key_id,
    :secret_access_key,
    :session_token,
    :expiration,
    :role_arn,
    :session_name,
    :duration_seconds
  ]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current temporary credentials.
  """
  def get_credentials do
    GenServer.call(__MODULE__, :get_credentials)
  end

  @doc """
  Forces a refresh of credentials.
  """
  def refresh_credentials do
    GenServer.call(__MODULE__, :refresh_credentials)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    role_arn = Keyword.get(opts, :role_arn) || System.get_env("AWS_ROLE_ARN")
    session_name = Keyword.get(opts, :session_name) || generate_session_name()
    duration_seconds = Keyword.get(opts, :duration_seconds, @default_duration_seconds)

    if is_nil(role_arn) do
      Logger.warning("AWS_ROLE_ARN not configured. STS credentials will not be available.")
      {:ok, nil}
    else
      state = %__MODULE__{
        role_arn: role_arn,
        session_name: session_name,
        duration_seconds: duration_seconds
      }

      case assume_role(state) do
        {:ok, new_state} ->
          schedule_refresh(new_state)
          {:ok, new_state}

        {:error, reason} ->
          Logger.error("Failed to assume role: #{inspect(reason)}")
          {:stop, reason}
      end
    end
  end

  @impl true
  def handle_call(:get_credentials, _from, nil) do
    {:reply, {:error, :sts_not_configured}, nil}
  end

  @impl true
  def handle_call(:get_credentials, _from, state) do
    credentials = %{
      access_key_id: state.access_key_id,
      secret_access_key: state.secret_access_key,
      session_token: state.session_token
    }

    {:reply, {:ok, credentials}, state}
  end

  @impl true
  def handle_call(:refresh_credentials, _from, state) do
    case assume_role(state) do
      {:ok, new_state} ->
        schedule_refresh(new_state)
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to refresh credentials: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:refresh, state) do
    case assume_role(state) do
      {:ok, new_state} ->
        Logger.info("Successfully refreshed STS credentials")
        schedule_refresh(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to refresh STS credentials: #{inspect(reason)}")
        # Retry in 1 minute
        Process.send_after(self(), :refresh, 60_000)
        {:noreply, state}
    end
  end

  # Private Functions

  @spec assume_role(t()) :: {:ok, t()} | {:error, term()}
  defp assume_role(state) do
    Logger.info("Assuming role: #{state.role_arn}")

    # Use base credentials (IAM user or instance profile) to assume the role
    result =
      ExAws.STS.assume_role(
        state.role_arn,
        state.session_name,
        duration: state.duration_seconds
      )
      |> ExAws.request()

    case result do
      {:ok, %{body: body}} ->
        credentials = body.credentials

        new_state = %{
          state
          | access_key_id: credentials.access_key_id,
            secret_access_key: credentials.secret_access_key,
            session_token: credentials.session_token,
            expiration: parse_expiration(credentials.expiration)
        }

        {:ok, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec schedule_refresh(t()) :: reference()
  defp schedule_refresh(state) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    expiration = DateTime.to_unix(state.expiration)
    time_until_expiry = expiration - now
    refresh_in = max(time_until_expiry - @refresh_before_expiry_seconds, 60) * 1000

    Logger.debug("Scheduling credential refresh in #{refresh_in / 1000} seconds")
    Process.send_after(self(), :refresh, refresh_in)
  end

  @spec parse_expiration(String.t()) :: DateTime.t()
  defp parse_expiration(expiration_string) do
    case DateTime.from_iso8601(expiration_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> DateTime.utc_now() |> DateTime.add(@default_duration_seconds, :second)
    end
  end

  defp generate_session_name do
    "shadowfax-#{System.get_env("HOSTNAME", "unknown")}-#{:os.system_time(:second)}"
  end
end
