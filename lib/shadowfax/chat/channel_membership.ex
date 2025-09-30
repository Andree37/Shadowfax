defmodule Shadowfax.Chat.ChannelMembership do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.Channel

  schema "channel_memberships" do
    field :role, :string, default: "member"
    field :joined_at, :naive_datetime
    field :last_read_at, :naive_datetime
    field :is_muted, :boolean, default: false
    field :notification_preference, :string, default: "all"

    # Associations
    belongs_to :user, User
    belongs_to :channel, Channel

    timestamps()
  end

  @doc """
  A channel membership changeset for creating memberships.
  """
  def create_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :channel_id, :role, :joined_at])
    |> validate_required([:user_id, :channel_id])
    |> validate_role()
    |> validate_notification_preference()
    |> put_joined_at()
    |> unique_constraint([:user_id, :channel_id])
  end

  @doc """
  A channel membership changeset for updating membership settings.
  """
  def update_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:is_muted, :notification_preference, :last_read_at])
    |> validate_notification_preference()
  end

  @doc """
  A channel membership changeset for updating user roles.
  """
  def role_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_role()
  end

  defp validate_role(changeset) do
    valid_roles = ["member", "admin", "owner"]
    validate_inclusion(changeset, :role, valid_roles)
  end

  defp validate_notification_preference(changeset) do
    valid_preferences = ["all", "mentions", "none"]
    validate_inclusion(changeset, :notification_preference, valid_preferences)
  end

  defp put_joined_at(changeset) do
    case get_field(changeset, :joined_at) do
      nil -> put_change(changeset, :joined_at, NaiveDateTime.utc_now())
      _ -> changeset
    end
  end

  @doc """
  Returns a query for all memberships in a channel.
  """
  def channel_memberships_query(channel_id) do
    from cm in __MODULE__,
      where: cm.channel_id == ^channel_id,
      preload: [:user]
  end

  @doc """
  Returns a query for all memberships of a user.
  """
  def user_memberships_query(user_id) do
    from cm in __MODULE__,
      where: cm.user_id == ^user_id,
      preload: [:channel]
  end

  @doc """
  Returns a query for admins and owners of a channel.
  """
  def channel_moderators_query(channel_id) do
    from cm in __MODULE__,
      where: cm.channel_id == ^channel_id and cm.role in ["admin", "owner"],
      preload: [:user]
  end

  @doc """
  Finds a specific membership.
  """
  def find_membership(user_id, channel_id) do
    from cm in __MODULE__,
      where: cm.user_id == ^user_id and cm.channel_id == ^channel_id
  end

  @doc """
  Checks if a user has unread messages in a channel.
  """
  def has_unread_messages?(%__MODULE__{channel_id: channel_id, last_read_at: last_read_at}) do
    if last_read_at do
      from(m in Shadowfax.Chat.Message,
        where: m.channel_id == ^channel_id and m.inserted_at > ^last_read_at
      )
      |> Shadowfax.Repo.exists?()
    else
      # If never read, check if there are any messages
      from(m in Shadowfax.Chat.Message,
        where: m.channel_id == ^channel_id
      )
      |> Shadowfax.Repo.exists?()
    end
  end

  @doc """
  Gets the count of unread messages in a channel for this membership.
  """
  def unread_message_count(%__MODULE__{channel_id: channel_id, last_read_at: last_read_at}) do
    query =
      if last_read_at do
        from(m in Shadowfax.Chat.Message,
          where: m.channel_id == ^channel_id and m.inserted_at > ^last_read_at
        )
      else
        from(m in Shadowfax.Chat.Message,
          where: m.channel_id == ^channel_id
        )
      end

    Shadowfax.Repo.aggregate(query, :count)
  end

  @doc """
  Marks all messages in a channel as read for this membership.
  """
  def mark_as_read(membership) do
    membership
    |> change(%{last_read_at: NaiveDateTime.utc_now()})
    |> Shadowfax.Repo.update()
  end

  @doc """
  Checks if the user should receive notifications for this channel.
  """
  def should_notify?(%__MODULE__{is_muted: true}), do: false
  def should_notify?(%__MODULE__{notification_preference: "none"}), do: false
  def should_notify?(%__MODULE__{notification_preference: "all"}), do: true
  def should_notify?(%__MODULE__{notification_preference: "mentions"}), do: :mentions_only

  @doc """
  Returns the display role name.
  """
  def display_role(%__MODULE__{role: "owner"}), do: "Owner"
  def display_role(%__MODULE__{role: "admin"}), do: "Admin"
  def display_role(%__MODULE__{role: "member"}), do: "Member"
  def display_role(%__MODULE__{role: role}), do: String.capitalize(role)
end
