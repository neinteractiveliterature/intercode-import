# frozen_string_literal: true

require 'test_helper'

class MarkdownifierTest < Minitest::Test
  def setup
    @m = IntercodeImport::Markdownifier.new(SILENT_LOGGER)
  end

  def test_nil_returns_nil
    assert_nil @m.markdownify(nil)
  end

  def test_blank_string_returns_nil
    assert_nil @m.markdownify('')
  end

  def test_plain_paragraph
    result = @m.markdownify('<p>Hello world</p>')
    assert_includes result, 'Hello world'
  end

  def test_bold_tag
    result = @m.markdownify('<b>Bold</b>')
    assert_includes result, '**Bold**'
  end

  def test_italic_tag
    result = @m.markdownify('<i>Italic</i>')
    assert_includes result, '_Italic_'
  end

  def test_hyperlink
    result = @m.markdownify('<a href="https://example.com">Click here</a>')
    assert_includes result, '[Click here](https://example.com)'
  end

  def test_youtube_object_embed
    html = <<~HTML
      <object>
        <param name="movie" value="http://www.youtube.com/v/dQw4w9WgXcQ&amp;hl=en" />
        <param name="allowFullScreen" value="true" />
      </object>
    HTML
    result = @m.markdownify(html)
    assert_includes result, '{% youtube dQw4w9WgXcQ %}'
    refute_includes result, '<object>'
  end

  def test_youtube_video_id_with_hyphens
    html = '<object><param name="movie" value="http://www.youtube.com/v/aB-c-D1234E" /></object>'
    result = @m.markdownify(html)
    assert_includes result, '{% youtube aB-c-D1234E %}'
  end
end
