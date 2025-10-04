defmodule Shadowfax.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.{Channel, DirectConversation}

  schema "messages" do
    field :content, :string
    field :message_type, :string, default: "text"
    field :edited_at, :naive_datetime
    field :is_deleted, :boolean, default: false
    field :metadata, :map
    field :attachments, {:array, :map}, default: []

    # Associations
    belongs_to :user, User
    belongs_to :channel, Channel
    belongs_to :direct_conversation, DirectConversation
    belongs_to :parent_message, __MODULE__
    has_many :replies, __MODULE__, foreign_key: :parent_message_id

    timestamps()
  end

  @doc """
  A message changeset for creating channel messages.
  """
  def channel_message_changeset(message, attrs) do
    message
    |> cast(attrs, [
      :content,
      :message_type,
      :user_id,
      :channel_id,
      :parent_message_id,
      :metadata,
      :attachments
    ])
    |> validate_required([:content, :user_id, :channel_id])
    |> validate_message_type()
    |> validate_content()
    |> validate_channel_message()
    |> validate_parent_message()
  end

  @doc """
  A message changeset for creating direct messages.
  """
  def direct_message_changeset(message, attrs) do
    message
    |> cast(attrs, [
      :content,
      :message_type,
      :user_id,
      :direct_conversation_id,
      :parent_message_id,
      :metadata,
      :attachments
    ])
    |> validate_required([:content, :user_id, :direct_conversation_id])
    |> validate_message_type()
    |> validate_content()
    |> validate_direct_message()
    |> validate_parent_message()
  end

  @doc """
  A message changeset for editing messages.
  """
  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> validate_content()
    |> put_change(:edited_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end

  @doc """
  A message changeset for soft deleting messages.
  """
  def delete_changeset(message) do
    message
    |> change(%{is_deleted: true})
  end

  defp validate_message_type(changeset) do
    valid_types = ["text", "image", "file", "system", "thread"]
    validate_inclusion(changeset, :message_type, valid_types)
  end

  defp validate_content(changeset) do
    changeset
    |> validate_required([:content])
    |> validate_length(:content, min: 1, max: 4000)
  end

  defp validate_channel_message(changeset) do
    # Ensure this is a channel message (not a direct message)
    if get_field(changeset, :direct_conversation_id) do
      add_error(changeset, :channel_id, "cannot be set when direct_conversation_id is present")
    else
      changeset
    end
  end

  defp validate_direct_message(changeset) do
    # Ensure this is a direct message (not a channel message)
    if get_field(changeset, :channel_id) do
      add_error(changeset, :direct_conversation_id, "cannot be set when channel_id is present")
    else
      changeset
    end
  end

  defp validate_parent_message(changeset) do
    parent_message_id = get_field(changeset, :parent_message_id)
    channel_id = get_field(changeset, :channel_id)
    direct_conversation_id = get_field(changeset, :direct_conversation_id)

    if parent_message_id do
      case Shadowfax.Repo.get(__MODULE__, parent_message_id) do
        nil ->
          add_error(changeset, :parent_message_id, "parent message does not exist")

        parent_message ->
          cond do
            channel_id && parent_message.channel_id != channel_id ->
              add_error(
                changeset,
                :parent_message_id,
                "parent message must be in the same channel"
              )

            direct_conversation_id &&
                parent_message.direct_conversation_id != direct_conversation_id ->
              add_error(
                changeset,
                :parent_message_id,
                "parent message must be in the same conversation"
              )

            true ->
              changeset
          end
      end
    else
      changeset
    end
  end

  @doc """
  Returns a query for messages in a channel with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 50)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after
  """
  def channel_messages_query(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)

    query =
      from m in __MODULE__,
        where: m.channel_id == ^channel_id and m.is_deleted == false,
        preload: [:user, :parent_message]

    query = apply_cursor_filters(query, before_cursor, after_cursor)

    from m in query,
      order_by: [desc: m.id],
      limit: ^limit
  end

  @doc """
  Returns a query for messages in a direct conversation with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 50)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after
  """
  def direct_messages_query(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)

    query =
      from m in __MODULE__,
        where: m.direct_conversation_id == ^conversation_id and m.is_deleted == false,
        preload: [:user, :parent_message]

    query = apply_cursor_filters(query, before_cursor, after_cursor)

    from m in query,
      order_by: [desc: m.id],
      limit: ^limit
  end

  defp apply_cursor_filters(query, nil, nil), do: query

  defp apply_cursor_filters(query, before_cursor, nil) when not is_nil(before_cursor) do
    from m in query, where: m.id < ^before_cursor
  end

  defp apply_cursor_filters(query, nil, after_cursor) when not is_nil(after_cursor) do
    from m in query, where: m.id > ^after_cursor
  end

  defp apply_cursor_filters(query, before_cursor, after_cursor) do
    from m in query,
      where: m.id < ^before_cursor and m.id > ^after_cursor
  end

  @doc """
  Returns a query for thread messages (replies to a parent message) with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 50)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after
  """
  def thread_messages_query(parent_message_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)

    query =
      from m in __MODULE__,
        where: m.parent_message_id == ^parent_message_id and m.is_deleted == false,
        preload: [:user]

    query = apply_cursor_filters(query, before_cursor, after_cursor)

    from m in query,
      order_by: [asc: m.id],
      limit: ^limit
  end

  @doc """
  Returns a query for recent messages by a user with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 20)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after
  """
  def user_recent_messages_query(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)

    query =
      from m in __MODULE__,
        where: m.user_id == ^user_id and m.is_deleted == false,
        preload: [:channel, :direct_conversation]

    query = apply_cursor_filters(query, before_cursor, after_cursor)

    from m in query,
      order_by: [desc: m.id],
      limit: ^limit
  end

  @doc """
  Search messages by content with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 25)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after
  - `:channel_id` - Filter by channel ID
  - `:conversation_id` - Filter by conversation ID
  - `:user_id` - Filter by user ID
  """
  def search_messages_query(search_term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)
    channel_id = Keyword.get(opts, :channel_id)
    conversation_id = Keyword.get(opts, :conversation_id)
    user_id = Keyword.get(opts, :user_id)

    query =
      from m in __MODULE__,
        where: m.is_deleted == false and ilike(m.content, ^"%#{search_term}%"),
        preload: [:user, :channel, :direct_conversation]

    query = if channel_id, do: where(query, [m], m.channel_id == ^channel_id), else: query

    query =
      if conversation_id,
        do: where(query, [m], m.direct_conversation_id == ^conversation_id),
        else: query

    query = if user_id, do: where(query, [m], m.user_id == ^user_id), else: query

    query = apply_cursor_filters(query, before_cursor, after_cursor)

    from m in query,
      order_by: [desc: m.id],
      limit: ^limit
  end

  @doc """
  Checks if a message can be edited by a user.
  """
  def can_edit?(%__MODULE__{user_id: user_id, inserted_at: inserted_at}, current_user_id) do
    # Users can edit their own messages within 15 minutes
    user_id == current_user_id and
      NaiveDateTime.diff(NaiveDateTime.utc_now(), inserted_at, :minute) <= 15
  end

  @doc """
  Checks if a message can be deleted by a user.
  """
  def can_delete?(%__MODULE__{user_id: user_id}, current_user_id, user_role \\ "member") do
    # Users can delete their own messages, or admins/owners can delete any message
    user_id == current_user_id or user_role in ["admin", "owner"]
  end

  @doc """
  Checks if a message is a thread reply.
  """
  def is_thread_reply?(%__MODULE__{parent_message_id: parent_message_id}) do
    not is_nil(parent_message_id)
  end

  @doc """
  Checks if a message has been edited.
  """
  def edited?(%__MODULE__{edited_at: edited_at}) do
    not is_nil(edited_at)
  end

  @doc """
  Gets the reply count for a message.
  """
  def reply_count(%__MODULE__{id: message_id}) do
    from(m in __MODULE__,
      where: m.parent_message_id == ^message_id and m.is_deleted == false
    )
    |> Shadowfax.Repo.aggregate(:count)
  end

  @doc """
  Formats message content for display, handling mentions, links, etc.
  """
  def format_content(%__MODULE__{content: content, message_type: "text"}) do
    content
    |> format_mentions()
    |> format_links()
    |> format_markdown()
  end

  def format_content(%__MODULE__{content: content}), do: content

  defp format_mentions(content) do
    # Simple mention formatting - replace @username with formatted version
    Regex.replace(~r/@(\w+)/, content, "<span class=\"mention\">@\\1</span>")
  end

  defp format_links(content) do
    # Simple link formatting
    Regex.replace(
      ~r/https?:\/\/[^\s]+/,
      content,
      "<a href=\"&\" target=\"_blank\" class=\"message-link\">&</a>"
    )
  end

  defp format_markdown(content) do
    # Basic markdown formatting
    content
    |> String.replace(~r/\*\*(.*?)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*(.*?)\*/, "<em>\\1</em>")
    |> String.replace(~r/`(.*?)`/, "<code>\\1</code>")
  end

  @doc """
  Creates a system message (for join/leave notifications, etc.).
  """
  def system_message_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:content, :user_id, :channel_id, :direct_conversation_id, :metadata])
    |> put_change(:message_type, "system")
    |> validate_required([:content])
    |> validate_system_message()
  end

  defp validate_system_message(changeset) do
    channel_id = get_field(changeset, :channel_id)
    direct_conversation_id = get_field(changeset, :direct_conversation_id)

    if channel_id && direct_conversation_id do
      add_error(changeset, :base, "system message cannot belong to both channel and conversation")
    else
      changeset
    end
  end

  @doc """
  Gets message context (channel or conversation info).
  """
  def get_context(%__MODULE__{channel: %Channel{} = channel}), do: {:channel, channel}

  def get_context(%__MODULE__{direct_conversation: %DirectConversation{} = conv}),
    do: {:conversation, conv}

  def get_context(%__MODULE__{channel_id: channel_id}) when not is_nil(channel_id),
    do: {:channel, channel_id}

  def get_context(%__MODULE__{direct_conversation_id: conv_id}) when not is_nil(conv_id),
    do: {:conversation, conv_id}

  def get_context(_), do: {:unknown, nil}
end
