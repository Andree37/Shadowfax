defmodule Shadowfax.UploadTest do
  use ExUnit.Case, async: true

  alias Shadowfax.Upload

  describe "validate_file_size/1" do
    test "accepts files under max size" do
      assert :ok = Upload.validate_file_size(1024)
      assert :ok = Upload.validate_file_size(50 * 1024 * 1024)
    end

    test "rejects files over max size" do
      assert {:error, message} = Upload.validate_file_size(50 * 1024 * 1024 + 1)
      assert message =~ "exceeds maximum"
    end
  end

  describe "validate_content_type/1" do
    test "accepts allowed image types" do
      assert :ok = Upload.validate_content_type("image/png")
      assert :ok = Upload.validate_content_type("image/jpeg")
      assert :ok = Upload.validate_content_type("image/jpg")
      assert :ok = Upload.validate_content_type("image/gif")
      assert :ok = Upload.validate_content_type("image/webp")
    end

    test "accepts allowed document types" do
      assert :ok = Upload.validate_content_type("application/pdf")
      assert :ok = Upload.validate_content_type("text/plain")
      assert :ok = Upload.validate_content_type("application/msword")

      assert :ok =
               Upload.validate_content_type(
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
               )

      assert :ok = Upload.validate_content_type("application/vnd.ms-excel")

      assert :ok =
               Upload.validate_content_type(
                 "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
               )
    end

    test "rejects disallowed content types" do
      assert {:error, message} = Upload.validate_content_type("application/exe")
      assert message =~ "not allowed"

      assert {:error, message} = Upload.validate_content_type("video/mp4")
      assert message =~ "not allowed"
    end
  end

  describe "is_image?/1" do
    test "returns true for image types" do
      assert Upload.is_image?("image/png") == true
      assert Upload.is_image?("image/jpeg") == true
    end

    test "returns false for non-image types" do
      assert Upload.is_image?("application/pdf") == false
      assert Upload.is_image?("text/plain") == false
    end
  end

  describe "build_attachment_metadata/4" do
    test "builds correct metadata structure" do
      s3_key = "uploads/2025/01/15/timestamp-uuid.png"
      filename = "test.png"
      content_type = "image/png"
      size = 12345

      metadata = Upload.build_attachment_metadata(s3_key, filename, content_type, size)

      assert is_binary(metadata.id)
      assert metadata.filename == filename
      assert metadata.content_type == content_type
      assert metadata.size == size
      assert metadata.s3_key == s3_key
      assert metadata.url =~ "s3"
      assert metadata.url =~ s3_key
    end
  end
end
