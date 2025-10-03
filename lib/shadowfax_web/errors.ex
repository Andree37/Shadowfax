defmodule ShadowfaxWeb.Errors do
  @moduledoc """
  Standardized error messages and HTTP response constants for the API.

  This module provides consistent error messages across all controllers and plugs,
  ensuring a uniform API error response format.
  """

  # Authentication Errors (401)
  @doc "Missing or malformed Authorization header"
  def missing_authorization, do: "Missing authorization header"

  @doc "Invalid or malformed token"
  def invalid_token, do: "Invalid token"

  @doc "Token has expired"
  def token_expired, do: "Token expired"

  @doc "Token has been revoked/blacklisted"
  def token_revoked, do: "Token has been revoked"

  @doc "Wrong token type used (e.g., refresh token used as access token)"
  def invalid_token_type, do: "Invalid token type"

  @doc "User associated with token no longer exists"
  def user_not_found, do: "User not found"

  # Authorization Errors (403)
  @doc "User lacks permission for the requested resource"
  def access_denied, do: "Access denied"

  @doc "User is not a member of the channel"
  def not_channel_member, do: "You are not a member of this channel"

  @doc "User is not part of the conversation"
  def not_conversation_member, do: "You are not part of this conversation"

  # Rate Limiting (429)
  @doc "Rate limit exceeded"
  def rate_limit_exceeded, do: "Rate limit exceeded. Please try again later."

  # Validation Errors (422)
  @doc "Invalid or missing credentials"
  def invalid_credentials, do: "Invalid email or password"

  @doc "Missing required field"
  def missing_field(field), do: "#{field} is required"

  # Resource Errors (404)
  @doc "Resource not found"
  def not_found(resource \\ "Resource"), do: "#{resource} not found"

  @doc "Channel not found"
  def channel_not_found, do: "Channel not found"

  @doc "Conversation not found"
  def conversation_not_found, do: "Conversation not found"

  @doc "Message not found"
  def message_not_found, do: "Message not found"

  @doc "Session not found"
  def session_not_found, do: "Session not found"

  # Permission/Access Errors (Additional 403)
  @doc "Cannot access private channel"
  def channel_private, do: "Access denied. Channel is private."

  @doc "Admin or owner privileges required"
  def admin_required, do: "Access denied. Admin or owner privileges required."

  @doc "Can only update own profile"
  def own_profile_only, do: "You can only update your own profile"

  @doc "Can only edit own messages within time limit"
  def own_message_edit_only, do: "You can only edit your own messages within 15 minutes"

  @doc "Can only delete own messages or need admin"
  def delete_permission_denied,
    do: "You can only delete your own messages or you need admin/owner privileges"

  @doc "Already a member of channel"
  def already_member, do: "You are already a member of this channel"

  @doc "Must be channel member to post"
  def must_be_member, do: "Access denied. You must be a member of this channel."

  @doc "Cannot join channel"
  def cannot_join_channel, do: "Cannot join this channel. Check if it's private or at capacity."

  @doc "Cannot create conversation with yourself"
  def self_conversation, do: "Cannot create conversation with yourself"

  # Validation/Request Errors (Additional 400/422)
  @doc "Invalid request format"
  def invalid_request(expected), do: "Invalid request format. Expected '#{expected}' parameter."

  @doc "Invalid limit or offset parameter"
  def invalid_pagination, do: "Invalid limit or offset parameter"

  @doc "Search query required"
  def search_query_required, do: "Search query 'q' parameter is required and cannot be empty"

  @doc "Email and password required"
  def credentials_required, do: "Email and password are required"

  @doc "Invalid or expired refresh token"
  def invalid_refresh_token, do: "Invalid or expired refresh token"

  @doc "Refresh token required"
  def refresh_token_required, do: "Refresh token is required"

  @doc "Invalid token ID"
  def invalid_token_id, do: "Invalid token ID"

  @doc "Invalid or expired token (generic)"
  def invalid_or_expired_token, do: "Invalid or expired token"

  @doc "Not authenticated"
  def not_authenticated, do: "Not authenticated"

  # WebSocket/Channel specific errors (as atoms/strings for channel replies)
  @doc "Unauthorized WebSocket access"
  def ws_unauthorized, do: "unauthorized"

  @doc "Message not found in WebSocket context"
  def ws_message_not_found, do: "message_not_found"

  @doc "Conversation not found in WebSocket context"
  def ws_conversation_not_found, do: "conversation_not_found"

  @doc "Failed to mark as read"
  def ws_mark_read_failed, do: "failed_to_mark_as_read"

  # Helper to create standard error response
  @doc """
  Creates a standard JSON error response map.

  ## Examples

      iex> ShadowfaxWeb.Errors.error_response(missing_authorization())
      %{success: false, error: "Missing authorization header"}
  """
  def error_response(message) do
    %{
      success: false,
      error: message
    }
  end

  @doc """
  Creates a standard WebSocket error response map.
  Used in Phoenix Channels for consistency with HTTP errors.

  ## Examples

      iex> ShadowfaxWeb.Errors.ws_error_response(ws_unauthorized())
      %{reason: "unauthorized"}
  """
  def ws_error_response(reason) do
    %{reason: reason}
  end
end
