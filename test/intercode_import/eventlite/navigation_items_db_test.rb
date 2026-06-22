# frozen_string_literal: true

require 'test_helper'

class EventliteNavigationItemsDbTest < Minitest::Test
  include EventliteDbTestHelper

  def self.setup_db(db)
    db.create_table!(:events) do
      primary_key :id
      String :name
    end
    db.create_table!(:pages) do
      primary_key :id
      String  :name
      String  :slug
      String  :content
      Integer :parent_id
      String  :parent_type
    end
    db.create_table!(:navigation_items) do
      primary_key :id
      String  :title
      Integer :page_id
      Integer :navigation_section_id
      Integer :parent_id
      String  :parent_type
      Integer :position
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:navigation_items)
    db.drop_table?(:pages)
    db.drop_table?(:events)
  end

  def truncate_tables(db)
    db[:navigation_items].delete
    db[:pages].delete
    db[:events].delete
  end

  def setup
    super
    @event_id = @db[:events].insert(name: 'Test Event')
    @page_id  = @db[:pages].insert(name: 'Home', slug: 'home',
                                   parent_type: 'Event', parent_id: @event_id)
  end

  def export_nav
    IntercodeImport::Eventlite::Tables::NavigationItems.new(@db, @event_id).export!
  end

  def test_returns_empty_when_no_items
    assert_empty export_nav
  end

  def test_standalone_link_produces_own_section
    @db[:navigation_items].insert(title: 'Home', page_id: @page_id, position: 1,
                                  parent_type: 'Event', parent_id: @event_id)
    sections = export_nav
    assert_equal 1, sections.size
    assert_equal 'Home', sections.first[:title]
    assert_equal [{ title: 'Home', page_name: 'Home' }], sections.first[:links]
  end

  def test_section_header_with_children
    section_id = @db[:navigation_items].insert(title: 'Info', page_id: nil, position: 1,
                                               parent_type: 'Event', parent_id: @event_id)
    @db[:navigation_items].insert(title: 'Home', page_id: @page_id, position: 1,
                                  navigation_section_id: section_id,
                                  parent_type: 'Event', parent_id: @event_id)
    sections = export_nav
    assert_equal 1, sections.size
    assert_equal 'Info', sections.first[:title]
    assert_equal [{ title: 'Home', page_name: 'Home' }], sections.first[:links]
  end

  def test_section_header_with_no_valid_children_excluded
    section_id = @db[:navigation_items].insert(title: 'Info', page_id: nil, position: 1,
                                               parent_type: 'Event', parent_id: @event_id)
    reg_page_id = @db[:pages].insert(name: 'Registration', slug: 'registration',
                                     content: '{% ticket_form %}',
                                     parent_type: 'Event', parent_id: @event_id)
    @db[:navigation_items].insert(title: 'Register', page_id: reg_page_id, position: 1,
                                  navigation_section_id: section_id,
                                  parent_type: 'Event', parent_id: @event_id)
    assert_empty export_nav
  end

  def test_standalone_links_ordered_by_position
    page2_id = @db[:pages].insert(name: 'About', slug: 'about',
                                  parent_type: 'Event', parent_id: @event_id)
    @db[:navigation_items].insert(title: 'About', page_id: page2_id, position: 2,
                                  parent_type: 'Event', parent_id: @event_id)
    @db[:navigation_items].insert(title: 'Home', page_id: @page_id, position: 1,
                                  parent_type: 'Event', parent_id: @event_id)
    sections = export_nav
    assert_equal ['Home', 'About'], sections.map { |s| s[:title] }
  end

  def test_global_nav_items_included
    global_page_id = @db[:pages].insert(name: 'Info', slug: 'info', parent_type: nil, parent_id: nil)
    @db[:navigation_items].insert(title: 'Info', page_id: global_page_id, position: 1,
                                  parent_type: nil, parent_id: nil)
    assert_equal 1, export_nav.size
  end

  def test_other_event_items_excluded
    other_id = @db[:events].insert(name: 'Other')
    other_page_id = @db[:pages].insert(name: 'Other Home', slug: 'other-home',
                                       parent_type: 'Event', parent_id: other_id)
    @db[:navigation_items].insert(title: 'Other Home', page_id: other_page_id, position: 1,
                                  parent_type: 'Event', parent_id: other_id)
    assert_empty export_nav
  end

  def test_item_with_missing_page_skipped
    @db[:navigation_items].insert(title: 'Broken', page_id: 99999, position: 1,
                                  parent_type: 'Event', parent_id: @event_id)
    assert_empty export_nav
  end

  def test_nav_link_to_eventlite_only_page_skipped
    reg_page_id = @db[:pages].insert(name: 'Registration', slug: 'registration',
                                     content: '<h1>Register</h1>{% ticket_form %}',
                                     parent_type: 'Event', parent_id: @event_id)
    @db[:navigation_items].insert(title: 'Register', page_id: reg_page_id, position: 1,
                                  parent_type: 'Event', parent_id: @event_id)
    assert_empty export_nav
  end

  def test_nav_link_to_normal_page_kept_alongside_skipped_page
    reg_page_id = @db[:pages].insert(name: 'Registration', slug: 'registration',
                                     content: '{% ticket_form %}',
                                     parent_type: 'Event', parent_id: @event_id)
    @db[:navigation_items].insert(title: 'Register', page_id: reg_page_id, position: 2,
                                  parent_type: 'Event', parent_id: @event_id)
    @db[:navigation_items].insert(title: 'Home', page_id: @page_id, position: 1,
                                  parent_type: 'Event', parent_id: @event_id)
    sections = export_nav
    assert_equal 1, sections.size
    assert_equal 'Home', sections.first[:title]
    assert_equal [{ title: 'Home', page_name: 'Home' }], sections.first[:links]
  end
end
