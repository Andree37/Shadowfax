defmodule Shadowfax.Chat.DirectConversation do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.Message

  schema "direct_conversations" do
    field :last_message_at, :naive_datetime
    field :is_archived_by_user1, :boolean, default: false
    field :is_archived_by_user2, :boolean, default: false

    # Associations
    belongs_to :user1, User
    belongs_to :user2, User
    has_many :messages, Message, on_delete: :delete_all

    timestamps()
  end

  @doc """
  A direct conversation changeset for creating conversations.
  """
  def create_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:user1_id, :user2_id])
    |> validate_required([:user1_id, :user2_id])
    |> validate_different_users()
    |> ensure_user_order()
    |> unique_constraint([:user1_id, :user2_id])
  end

  @doc """
  A direct conversation changeset for updating last message time.
  """
  def update_last_message_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:last_message_at])
  end

  @doc """
  A direct conversation changeset for archiving/unarchiving.
  """
  def archive_changeset(conversation, user_id, is_archived) do
    field_name = archive_field_for_user(conversation, user_id)

    conversation
    |> change(%{field_name => is_archived})
  end

  defp validate_different_users(changeset) do
    user1_id = get_field(changeset, :user1_id)
    user2_id = get_field(changeset, :user2_id)

    if user1_id && user2_id && user1_id == user2_id do
      add_error(changeset, :user2_id, "cannot start a conversation with yourself")
    else
      changeset
    end
  end

  defp ensure_user_order(changeset) do
    user1_id = get_field(changeset, :user1_id)
    user2_id = get_field(changeset, :user2_id)

    if user1_id && user2_id && user1_id > user2_id do
      changeset
      |> put_change(:user1_id, user2_id)
      |> put_change(:user2_id, user1_id)
    else
      changeset
    end
  end

  @doc """
  Finds or creates a direct conversation between two users.
  """
  def find_or_create_conversation(user1_id, user2_id) do
    {lower_id, higher_id} =
      if user1_id < user2_id, do: {user1_id, user2_id}, else: {user2_id, user1_id}

    case find_conversation(lower_id, higher_id) do
      nil ->
        %__MODULE__{}
        |> create_changeset(%{user1_id: lower_id, user2_id: higher_id})
        |> Shadowfax.Repo.insert()

      conversation ->
        {:ok, conversation}
    end
  end

  @doc """
  Finds a direct conversation between two users.
  """
  def find_conversation(user1_id, user2_id) do
    {lower_id, higher_id} =
      if user1_id < user2_id, do: {user1_id, user2_id}, else: {user2_id, user1_id}

    from(dc in __MODULE__,
      where: dc.user1_id == ^lower_id and dc.user2_id == ^higher_id
    )
    |> Shadowfax.Repo.one()
  end

  @doc """
  Returns a query for all conversations for a user (not archived).
  """
  def user_conversations_query(user_id) do
    from dc in __MODULE__,
      where:
        (dc.user1_id == ^user_id and dc.is_archived_by_user1 == false) or
          (dc.user2_id == ^user_id and dc.is_archived_by_user2 == false),
      order_by: [desc: :last_message_at],
      preload: [:user1, :user2]
  end

  @doc """
  Returns a query for conversations with the latest message.
  """
  def with_latest_message_query do
    latest_messages =
      from m in Message,
        select: %{
          conversation_id: m.direct_conversation_id,
          latest_message_id: max(m.id)
        },
        where: not is_nil(m.direct_conversation_id),
        group_by: m.direct_conversation_id

    from dc in __MODULE__,
      left_join: lm in subquery(latest_messages),
      on: dc.id == lm.conversation_id,
      left_join: msg in Message,
      on: msg.id == lm.latest_message_id,
      preload: [latest_message: msg]
  end

  @doc """
  Gets the other user in the conversation.
  """
  def other_user(%__MODULE__{user1_id: user1_id, user2_id: user2_id}, current_user_id) do
    if current_user_id == user1_id, do: user2_id, else: user1_id
  end

  @doc """
  Gets the other user struct in the conversation.
  """
  def other_user_struct(%__MODULE__{user1: user1, user2: user2}, current_user_id) do
    if current_user_id == user1.id, do: user2, else: user1
  end

  @doc """
  Checks if a conversation is archived for a specific user.
  """
  def archived_for_user?(%__MODULE__{} = conversation, user_id) do
    field_name = archive_field_for_user(conversation, user_id)
    Map.get(conversation, field_name, false)
  end

  @doc """
  Updates the last message timestamp for a conversation.
  """
  def update_last_message_time(conversation_id) do
    now = NaiveDateTime.utc_now()

    from(dc in __MODULE__, where: dc.id == ^conversation_id)
    |> Shadowfax.Repo.update_all(set: [last_message_at: now])
  end

  @doc """
  Gets unread message count for a user in this conversation.
  """
  def unread_message_count(%__MODULE__{id: conversation_id}, user_id, last_read_at \\ nil) do
    query =
      from m in Message,
        where: m.direct_conversation_id == ^conversation_id and m.user_id != ^user_id

    query =
      if last_read_at do
        from m in query, where: m.inserted_at > ^last_read_at
      else
        query
      end

    Shadowfax.Repo.aggregate(query, :count)
  end

  @doc """
  Creates a display name for the conversation from the perspective of a user.
  """
  def display_name(%__MODULE__{} = conversation, current_user_id) do
    other_user = other_user_struct(conversation, current_user_id)
    User.display_name(other_user)
  end

  defp archive_field_for_user(%__MODULE__{user1_id: user1_id}, user_id)
       when user_id == user1_id do
    :is_archived_by_user1
  end

  defp archive_field_for_user(%__MODULE__{user2_id: user2_id}, user_id)
       when user_id == user2_id do
    :is_archived_by_user2
  end

  defp archive_field_for_user(_, _), do: nil
end
