# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class HtmlConverterTest < Minitest::Test
  def converter(html, source_dir: '/nonexistent')
    IntercodeImport::Intercode1::HtmlConverter.new(html: html, source_dir: source_dir)
  end

  def test_plain_link_is_unchanged
    result = converter('<a href="https://example.com">Link</a>').convert
    assert_includes result[:content], 'https://example.com'
  end

  def test_static_php_link_becomes_page_url_tag
    result = converter('<a href="static.php?page=About">About</a>').convert
    assert_includes result[:content], '{% page_url about %}'
  end

  def test_static_php_link_slugifies_page_name
    result = converter('<a href="Static.php?page=EventList">Events</a>').convert
    assert_includes result[:content], '{% page_url eventlist %}'
  end

  def test_con_com_schedule_link
    result = converter('<a href="ConComSchedule.php">Schedule</a>').convert
    assert_includes result[:content], '{% page_url con_com_schedule %}'
  end

  def test_h1_gets_my3_class
    result = converter('<h1>Title</h1>').convert
    assert_includes result[:content], 'class="my-3"'
  end

  def test_h4_gets_my2_class
    result = converter('<h4>Subtitle</h4>').convert
    assert_includes result[:content], 'class="my-2"'
  end

  def test_existing_heading_class_is_preserved
    result = converter('<h2 class="foo">Bar</h2>').convert
    assert_includes result[:content], 'foo my-3'
  end

  def test_nonexistent_local_image_href_unchanged
    result = converter('<img src="images/photo.jpg">').convert
    assert_includes result[:content], 'images/photo.jpg'
    assert_empty result[:local_files]
  end

  def test_existing_local_image_replaced_with_cms_file_url
    Dir.mktmpdir do |dir|
      FileUtils.touch(File.join(dir, 'photo.jpg'))
      result = converter('<img src="photo.jpg">', source_dir: dir).convert
      assert_includes result[:content], '{% file_url "photo.jpg" %}'
      assert_equal 1, result[:local_files].size
    end
  end

  def test_existing_local_pdf_link_replaced_with_cms_file_url
    Dir.mktmpdir do |dir|
      FileUtils.touch(File.join(dir, 'schedule.pdf'))
      result = converter('<a href="schedule.pdf">PDF</a>', source_dir: dir).convert
      assert_includes result[:content], '{% file_url "schedule.pdf" %}'
      assert_includes result[:local_files], File.join(dir, 'schedule.pdf')
    end
  end

  def test_nonexistent_pdf_link_is_unchanged
    result = converter('<a href="missing.pdf">PDF</a>').convert
    assert_includes result[:content], 'missing.pdf'
    assert_empty result[:local_files]
  end

  def test_absolute_url_image_is_not_treated_as_local
    result = converter('<img src="https://example.com/image.jpg">').convert
    assert_includes result[:content], 'https://example.com/image.jpg'
    assert_empty result[:local_files]
  end

  def test_local_files_is_a_set
    result = converter('<p>no files</p>').convert
    assert_kind_of Set, result[:local_files]
  end
end
