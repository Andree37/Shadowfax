defmodule Shadowfax.Chat.Channel do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.{ChannelMembership, Message}

  schema "channels" do
    field :name, :string
    field :description, :string
    field :topic, :string
    field :is_private, :boolean, default: false
    field :is_archived, :boolean, default: false
    field :max_members, :integer
    field :invite_code, :string

    # Associations
    belongs_to :created_by, User
    has_many :channel_memberships, ChannelMembership, on_delete: :delete_all
    has_many :members, through: [:channel_memberships, :user]
    has_many :messages, Message, on_delete: :delete_all

    timestamps()
  end

  @doc """
  A channel changeset for creating channels.
  """
  def create_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :topic, :is_private, :max_members, :created_by_id])
    |> validate_required([:name, :created_by_id])
    |> validate_name()
    |> validate_description()
    |> validate_max_members()
    |> maybe_generate_invite_code()
    |> unique_constraint(:name)
  end

  @doc """
  A channel changeset for updating channels.
  """
  def update_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :topic, :max_members])
    |> validate_name()
    |> validate_description()
    |> validate_max_members()
    |> unique_constraint(:name)
  end

  @doc """
  A channel changeset for archiving/unarchiving channels.
  """
  def archive_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:is_archived])
    |> validate_required([:is_archived])
  end

  @doc """
  A channel changeset for regenerating invite codes.
  """
  def invite_code_changeset(channel) do
    channel
    |> change()
    |> put_change(:invite_code, generate_invite_code())
    |> unique_constraint(:invite_code)
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 80)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/,
      message: "only letters, numbers, underscores, and hyphens allowed"
    )
    |> update_change(:name, &String.downcase/1)
  end

  defp validate_description(changeset) do
    changeset
    |> validate_length(:description, max: 250)
  end

  defp validate_max_members(changeset) do
    changeset
    |> validate_number(:max_members, greater_than: 0, less_than_or_equal_to: 10000)
  end

  defp maybe_generate_invite_code(changeset) do
    is_private = get_field(changeset, :is_private)

    if is_private do
      put_change(changeset, :invite_code, generate_invite_code())
    else
      changeset
    end
  end

  defp generate_invite_code do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64()
    |> String.replace(~r/[^a-zA-Z0-9]/, "")
    |> String.slice(0, 10)
  end

  @doc """
  Returns a query for all public channels.
  """
  def public_channels_query do
    from c in __MODULE__,
      where: c.is_private == false and c.is_archived == false,
      order_by: [asc: :name]
  end

  @doc """
  Returns a query for channels a user is a member of.
  """
  def user_channels_query(user_id) do
    from c in __MODULE__,
      join: cm in ChannelMembership,
      on: cm.channel_id == c.id,
      where: cm.user_id == ^user_id and c.is_archived == false,
      order_by: [asc: :name]
  end

  @doc """
  Returns a query for channels with member count.
  """
  def with_member_count_query do
    from c in __MODULE__,
      left_join: cm in ChannelMembership,
      on: cm.channel_id == c.id,
      group_by: c.id,
      select: %{c | member_count: count(cm.id)}
  end

  @doc """
  Checks if a channel is at capacity.
  """
  def at_capacity?(%__MODULE__{max_members: nil}), do: false

  def at_capacity?(%__MODULE__{max_members: max_members} = channel) do
    member_count = get_member_count(channel)
    member_count >= max_members
  end

  @doc """
  Gets the current member count for a channel.
  """
  def get_member_count(%__MODULE__{id: channel_id}) do
    from(cm in ChannelMembership, where: cm.channel_id == ^channel_id)
    |> Shadowfax.Repo.aggregate(:count)
  end

  @doc """
  Checks if a user can join a channel.
  """
  def can_join?(%__MODULE__{} = channel, user_id) do
    not is_member?(channel, user_id) and
      not at_capacity?(channel) and
      not channel.is_archived
  end

  @doc """
  Checks if a user is a member of a channel.
  """
  def is_member?(%__MODULE__{id: channel_id}, user_id) do
    from(cm in ChannelMembership,
      where: cm.channel_id == ^channel_id and cm.user_id == ^user_id
    )
    |> Shadowfax.Repo.exists?()
  end

  @doc """
  Gets a user's role in a channel.
  """
  def user_role(%__MODULE__{id: channel_id}, user_id) do
    from(cm in ChannelMembership,
      where: cm.channel_id == ^channel_id and cm.user_id == ^user_id,
      select: cm.role
    )
    |> Shadowfax.Repo.one()
  end

  @doc """
  Checks if a user is an admin or owner of a channel.
  """
  def user_can_moderate?(%__MODULE__{} = channel, user_id) do
    case user_role(channel, user_id) do
      role when role in ["admin", "owner"] -> true
      _ -> false
    end
  end

  @doc """
  Returns the channel's display name with # prefix for public channels.
  """
  def display_name(%__MODULE__{name: name, is_private: false}), do: "##{name}"
  def display_name(%__MODULE__{name: name, is_private: true}), do: name

  @doc """
  Finds a channel by invite code.
  """
  def find_by_invite_code(invite_code) when is_binary(invite_code) do
    from(c in __MODULE__,
      where: c.invite_code == ^invite_code and c.is_private == true and c.is_archived == false
    )
    |> Shadowfax.Repo.one()
  end
end
