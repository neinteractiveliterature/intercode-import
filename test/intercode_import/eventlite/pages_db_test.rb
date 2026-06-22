# frozen_string_literal: true

require 'test_helper'

class EventlitePagesDbTest < Minitest::Test
  include EventliteDbTestHelper

  def self.setup_db(db)
    db.create_table!(:events) do
      primary_key :id
      String :name
    end
    db.create_table!(:cms_layouts) do
      primary_key :id
      String  :name
      String  :content
      Integer :parent_id
      String  :parent_type
    end
    db.create_table!(:pages) do
      primary_key :id
      String  :name
      String  :slug
      String  :content
      Integer :cms_layout_id
      Integer :parent_id
      String  :parent_type
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:pages)
    db.drop_table?(:cms_layouts)
    db.drop_table?(:events)
  end

  def truncate_tables(db)
    db[:pages].delete
    db[:cms_layouts].delete
    db[:events].delete
  end

  def setup
    super
    @event_id = @db[:events].insert(name: 'Test Event')
  end

  def export_pages(layout_name_by_id = {})
    IntercodeImport::Eventlite::Tables::Pages.new(@db, @event_id, layout_name_by_id).export!
  end

  def test_event_scoped_page_exported
    @db[:pages].insert(name: 'Home', slug: 'home', content: 'Welcome!',
                       parent_type: 'Event', parent_id: @event_id)
    pages = export_pages
    assert_equal 1, pages.size
    p = pages.first
    assert_equal 'Home', p[:name]
    assert_equal 'home', p[:slug]
    assert_equal 'Welcome!', p[:content]
  end

  def test_global_page_included
    @db[:pages].insert(name: 'About', slug: 'about', content: 'About us',
                       parent_type: nil, parent_id: nil)
    assert_equal 1, export_pages.size
  end

  def test_other_event_page_excluded
    other_id = @db[:events].insert(name: 'Other')
    @db[:pages].insert(name: 'Other Page', slug: 'other', content: '',
                       parent_type: 'Event', parent_id: other_id)
    assert_empty export_pages
  end

  def test_cms_layout_name_included_when_mapped
    lid = @db[:cms_layouts].insert(name: 'Default', content: '',
                                   parent_type: 'Event', parent_id: @event_id)
    @db[:pages].insert(name: 'Home', slug: 'home', content: '',
                       cms_layout_id: lid, parent_type: 'Event', parent_id: @event_id)
    pages = export_pages(lid => 'Default')
    assert_equal 'Default', pages.first[:cms_layout_name]
  end

  def test_cms_layout_name_absent_when_not_mapped
    @db[:pages].insert(name: 'Home', slug: 'home', content: '',
                       parent_type: 'Event', parent_id: @event_id)
    pages = export_pages
    refute pages.first.key?(:cms_layout_name)
  end

  def test_nil_content_exported_as_empty_string
    @db[:pages].insert(name: 'Empty', slug: 'empty', content: nil,
                       parent_type: 'Event', parent_id: @event_id)
    assert_equal '', export_pages.first[:content]
  end

  def test_page_with_ticket_form_tag_skipped
    @db[:pages].insert(name: 'Registration', slug: 'registration',
                       content: '<h1>Register</h1>{% ticket_form %}',
                       parent_type: 'Event', parent_id: @event_id)
    assert_empty export_pages
  end

  def test_page_with_normal_liquid_tag_included
    @db[:pages].insert(name: 'Home', slug: 'home',
                       content: '{% if user %}Hello{% endif %}',
                       parent_type: 'Event', parent_id: @event_id)
    assert_equal 1, export_pages.size
  end
end
